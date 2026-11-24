-- ============================================================
-- Run this whole file once: Supabase Dashboard > SQL Editor > New query > paste > Run.
-- Safe to re-run. Contains (1) approved-phone lock, (2) admin password reset.
-- ============================================================

-- ============================================================
-- BRIDGE WATERS — Approved-phone lock (one phone per staff member)
-- Run in: Supabase Dashboard > SQL Editor > New Query. Safe to re-run.
-- Needs migration_md_workflow.sql to have been run first (uses my_role()).
--
-- How it works
--   * Every browser/phone gets a secret random ID the first time it opens the
--     portal. The app sends it with every request (header "x-device-id").
--   * A staff member's first sign-in on a phone creates a "pending" request.
--   * An Admin/MD approves it in the app (Devices page). Approving a new phone
--     for someone automatically retires their old one: ONE phone per person.
--   * The database itself refuses to return events/requisitions to a phone that
--     isn't approved, so it can't be bypassed from the browser.
--   * Admin and MD are exempt (they can sign in anywhere) so nobody gets locked out.
--   * The lock ships OFF. Staff register their phones, you approve the right ones,
--     then switch the lock ON from the Devices page. Nothing breaks on deploy.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- Safety net in case migration_md_workflow.sql wasn't run
CREATE OR REPLACE FUNCTION public.my_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT role FROM public.profiles WHERE id = auth.uid() $$;

-- ── 1. TABLES ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.app_settings (
  key   TEXT PRIMARY KEY,
  value JSONB NOT NULL
);
INSERT INTO public.app_settings (key, value) VALUES ('device_lock', 'false'::jsonb)
  ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.devices (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token_hash   TEXT NOT NULL,                 -- sha256 of the phone's secret ID
  label        TEXT NOT NULL DEFAULT 'Unknown phone',
  user_agent   TEXT,
  status       TEXT NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending','approved','revoked')),
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  approved_at  TIMESTAMPTZ,
  approved_by  UUID,
  last_seen_at TIMESTAMPTZ,
  UNIQUE (user_id, token_hash)
);
CREATE INDEX IF NOT EXISTS devices_user_idx ON public.devices (user_id);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices      ENABLE ROW LEVEL SECURITY;

-- Read-only from the app; every change goes through the functions below.
DROP POLICY IF EXISTS "settings_read" ON public.app_settings;
CREATE POLICY "settings_read" ON public.app_settings FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "devices_read" ON public.devices;
CREATE POLICY "devices_read" ON public.devices FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.my_role() IN ('admin','md'));

-- ── 2. HELPERS ────────────────────────────────────────────────────────────
-- The secret ID the app sent with this request (empty if none)
CREATE OR REPLACE FUNCTION public.request_device_token()
RETURNS TEXT LANGUAGE sql STABLE
AS $$
  SELECT COALESCE(NULLIF(current_setting('request.headers', true), '')::json ->> 'x-device-id', '')
$$;

CREATE OR REPLACE FUNCTION public.request_device_hash()
RETURNS TEXT LANGUAGE sql STABLE
AS $$
  SELECT encode(extensions.digest(convert_to(public.request_device_token(), 'utf8'), 'sha256'), 'hex')
$$;

CREATE OR REPLACE FUNCTION public.device_lock_on()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT COALESCE((SELECT (value)::text = 'true' FROM public.app_settings WHERE key = 'device_lock'), false) $$;

-- TRUE when this request may see business data
CREATE OR REPLACE FUNCTION public.device_ok()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT NOT public.device_lock_on()
      OR COALESCE(public.my_role() IN ('admin','md'), false)
      OR EXISTS (
           SELECT 1 FROM public.devices d
            WHERE d.user_id = auth.uid()
              AND d.status = 'approved'
              AND d.token_hash = public.request_device_hash()
              AND length(public.request_device_token()) >= 32
         )
$$;

-- ── 3. THE LOCK ITSELF ────────────────────────────────────────────────────
-- RESTRICTIVE policies are AND-ed with every other policy, so they hold even if
-- older, looser policies still exist on these tables.
DROP POLICY IF EXISTS "device_gate" ON public.events;
CREATE POLICY "device_gate" ON public.events AS RESTRICTIVE FOR ALL TO authenticated
  USING (public.device_ok()) WITH CHECK (public.device_ok());

DROP POLICY IF EXISTS "device_gate" ON public.requisitions;
CREATE POLICY "device_gate" ON public.requisitions AS RESTRICTIVE FOR ALL TO authenticated
  USING (public.device_ok()) WITH CHECK (public.device_ok());

-- ── 4. FUNCTIONS THE APP CALLS ────────────────────────────────────────────
-- Staff: "what's the state of this phone?"  Registers it as pending if new.
CREATE OR REPLACE FUNCTION public.check_device(p_label TEXT DEFAULT NULL, p_ua TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
  tok TEXT := public.request_device_token();
  h   TEXT := public.request_device_hash();
  lock_on BOOLEAN := public.device_lock_on();
  r   RECORD;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;

  IF public.my_role() IN ('admin','md') THEN
    RETURN jsonb_build_object('status','exempt','lock',lock_on);
  END IF;

  IF length(tok) < 32 THEN
    RETURN jsonb_build_object('status','revoked','lock',lock_on);
  END IF;

  SELECT * INTO r FROM public.devices WHERE user_id = uid AND token_hash = h;

  IF NOT FOUND THEN
    -- stop anyone flooding the admin with requests
    IF (SELECT count(*) FROM public.devices WHERE user_id = uid AND status = 'pending') >= 5 THEN
      DELETE FROM public.devices WHERE id = (
        SELECT id FROM public.devices WHERE user_id = uid AND status = 'pending'
         ORDER BY requested_at LIMIT 1);
    END IF;
    INSERT INTO public.devices (user_id, token_hash, label, user_agent)
    VALUES (uid, h, COALESCE(NULLIF(left(p_label, 80), ''), 'Unknown phone'), left(p_ua, 300))
    RETURNING * INTO r;
  ELSIF r.status = 'approved'
        AND (r.last_seen_at IS NULL OR r.last_seen_at < NOW() - INTERVAL '10 minutes') THEN
    UPDATE public.devices SET last_seen_at = NOW() WHERE id = r.id;
  END IF;

  RETURN jsonb_build_object('status', r.status, 'lock', lock_on);
END;
$$;

-- Admin/MD: approve a phone. The person's previous approved phone is retired.
CREATE OR REPLACE FUNCTION public.approve_device(p_id UUID)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE uid UUID;
BEGIN
  IF public.my_role() NOT IN ('admin','md') THEN RAISE EXCEPTION 'Not allowed'; END IF;
  SELECT user_id INTO uid FROM public.devices WHERE id = p_id;
  IF uid IS NULL THEN RAISE EXCEPTION 'Phone not found'; END IF;
  UPDATE public.devices SET status = 'revoked'
   WHERE user_id = uid AND status = 'approved' AND id <> p_id;
  UPDATE public.devices SET status = 'approved', approved_at = NOW(), approved_by = auth.uid()
   WHERE id = p_id;
END;
$$;

-- Admin/MD: remove or decline a phone
CREATE OR REPLACE FUNCTION public.revoke_device(p_id UUID)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF public.my_role() NOT IN ('admin','md') THEN RAISE EXCEPTION 'Not allowed'; END IF;
  UPDATE public.devices SET status = 'revoked' WHERE id = p_id;
END;
$$;

-- Admin/MD: switch the lock on or off
CREATE OR REPLACE FUNCTION public.set_device_lock(p_on BOOLEAN)
RETURNS VOID LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF public.my_role() NOT IN ('admin','md') THEN RAISE EXCEPTION 'Not allowed'; END IF;
  INSERT INTO public.app_settings (key, value) VALUES ('device_lock', to_jsonb(p_on))
    ON CONFLICT (key) DO UPDATE SET value = to_jsonb(p_on);
END;
$$;

REVOKE ALL ON FUNCTION public.check_device(TEXT,TEXT), public.approve_device(UUID),
                       public.revoke_device(UUID), public.set_device_lock(BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_device(TEXT,TEXT), public.approve_device(UUID),
                          public.revoke_device(UUID), public.set_device_lock(BOOLEAN) TO authenticated;

SELECT 'Approved-phone lock installed (lock is OFF until you switch it on) ✓' AS status;


-- ============================================================
-- Lets an Admin or the MD set a new password for a staff member
-- (used by the "Reset password" button on the HR and staff page).
-- Run once in Supabase Dashboard > SQL Editor.
-- Safe to re-run.
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_set_password(p_user uuid, p_password text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  caller_role text;
  target_role text;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
  IF caller_role IS NULL OR caller_role NOT IN ('admin', 'md') THEN
    RAISE EXCEPTION 'Only an Admin or the MD can reset passwords.';
  END IF;

  SELECT role INTO target_role FROM public.profiles WHERE id = p_user;
  IF target_role IS NULL THEN
    RAISE EXCEPTION 'Staff member not found.';
  END IF;

  -- Only the MD may reset the MD's password
  IF target_role = 'md' AND caller_role <> 'md' THEN
    RAISE EXCEPTION 'Only the MD can reset the MD password.';
  END IF;

  IF p_password IS NULL OR length(p_password) < 8 THEN
    RAISE EXCEPTION 'Password must be at least 8 characters.';
  END IF;

  UPDATE auth.users
     SET encrypted_password = crypt(p_password, gen_salt('bf')),
         updated_at = now()
   WHERE id = p_user;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_password(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_password(uuid, text) TO authenticated;


-- ── Requisition files (migration_requisition_files.sql) ──────────────

ALTER TABLE public.requisitions ADD COLUMN IF NOT EXISTS file     TEXT;
ALTER TABLE public.requisitions ADD COLUMN IF NOT EXISTS batch_id TEXT;

CREATE INDEX IF NOT EXISTS requisitions_file_idx ON public.requisitions (file);

CREATE TABLE IF NOT EXISTS public.requisition_files (
  name       TEXT PRIMARY KEY,
  sort_order INT  NOT NULL DEFAULT 0,
  active     BOOLEAN NOT NULL DEFAULT true
);
ALTER TABLE public.requisition_files ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "files_read" ON public.requisition_files;
CREATE POLICY "files_read" ON public.requisition_files
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "files_manage" ON public.requisition_files;
CREATE POLICY "files_manage" ON public.requisition_files
  FOR ALL TO authenticated
  USING (public.my_role() IN ('admin','md'))
  WITH CHECK (public.my_role() IN ('admin','md'));

INSERT INTO public.requisition_files (name, sort_order) VALUES
  ('Kitchen Hotel',1),('Kitchen Store',2),('Kitchen Park',3),('Disposable',4),
  ('Printing & Stationery',5),('All Bakeries',6),('Laundry',7),('House Keeping',8),
  ('Bar Drinks',9),('Staff Canteen',10),('Cleaning & Sanitation',11),('Ivy Water',12),
  ('Chivita',13),('Coco Coal',14),('Meat & Fish',15),('Ice Cream',16),('Ticket Paper',17)
ON CONFLICT (name) DO NOTHING;

-- Admin can also raise requisitions (as herself). Hers go straight to the cashier.
DROP POLICY IF EXISTS "req_insert" ON public.requisitions;
CREATE POLICY "req_insert" ON public.requisitions FOR INSERT TO authenticated
  WITH CHECK (public.my_role() IN ('banqueting_manager','storekeeper','admin') AND raised_by = auth.uid());

-- Only the MD can edit / reject requisitions the admin raised herself.
-- (Admin still reviews requisitions raised by other people.)
DROP POLICY IF EXISTS "req_update_review" ON public.requisitions;
DROP POLICY IF EXISTS "req_update_md"     ON public.requisitions;
DROP POLICY IF EXISTS "req_update_admin"  ON public.requisitions;
CREATE POLICY "req_update_md" ON public.requisitions FOR UPDATE TO authenticated
  USING (public.my_role() = 'md')
  WITH CHECK (public.my_role() = 'md');
CREATE POLICY "req_update_admin" ON public.requisitions FOR UPDATE TO authenticated
  USING (public.my_role() = 'admin' AND raised_by IS DISTINCT FROM auth.uid() AND raised_by_role IS DISTINCT FROM 'admin')
  WITH CHECK (public.my_role() = 'admin' AND raised_by IS DISTINCT FROM auth.uid() AND raised_by_role IS DISTINCT FROM 'admin');

-- ============================================================
-- PART: hall prices + requisition locations
-- ============================================================
-- 1. Halls: allow the new hall ids (the old list only allowed 5 halls)
ALTER TABLE public.events DROP CONSTRAINT IF EXISTS events_hall_id_check;
ALTER TABLE public.events ADD CONSTRAINT events_hall_id_check
  CHECK (hall_id IN (
    'william','seraphina','small_hall','restaurant','abuja_hall',
    'anambra','enugu_hall','board_room','lounge','delta','pool','placia_hall',
    'conference'   -- retired hall, kept so old bookings stay valid
  ));

-- 2. Every booking keeps a copy of the hall's standard price at the time it was
--    booked, next to "amount" (what it actually sold for). Auditors compare the two.
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS standard_price NUMERIC(15,2);
COMMENT ON COLUMN public.events.standard_price IS 'Standard price of the hall when booked. amount = what it sold for.';

-- Fill in the standard price on bookings made before this change (only where empty)
UPDATE public.events SET standard_price = CASE hall_id
  WHEN 'william'     THEN 1200000
  WHEN 'seraphina'   THEN 1000000
  WHEN 'small_hall'  THEN 200000
  WHEN 'restaurant'  THEN 100000
  WHEN 'abuja_hall'  THEN 400000
  WHEN 'anambra'     THEN 300000
  WHEN 'enugu_hall'  THEN 300000
  WHEN 'board_room'  THEN 120000
  WHEN 'lounge'      THEN 450000
  WHEN 'delta'       THEN 700000
  WHEN 'pool'        THEN 120000
  WHEN 'placia_hall' THEN 200000
  ELSE NULL END
WHERE standard_price IS NULL;

-- Once recorded, the standard price on a booking cannot be edited by anyone
CREATE OR REPLACE FUNCTION public.lock_standard_price()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.standard_price IS NOT NULL AND NEW.standard_price IS DISTINCT FROM OLD.standard_price THEN
    NEW.standard_price := OLD.standard_price;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS events_lock_standard_price ON public.events;
CREATE TRIGGER events_lock_standard_price BEFORE UPDATE ON public.events
  FOR EACH ROW EXECUTE FUNCTION public.lock_standard_price();

-- 3. Requisitions: which location (property) each one belongs to
ALTER TABLE public.requisitions ADD COLUMN IF NOT EXISTS property_id TEXT;

-- Old requisitions: take the location from whoever raised them (if their profile has one)
UPDATE public.requisitions r
   SET property_id = p.property_id
  FROM public.profiles p
 WHERE r.property_id IS NULL AND r.raised_by = p.id AND p.property_id IS NOT NULL;

SELECT 'Hall prices and requisition locations ready' AS status;
