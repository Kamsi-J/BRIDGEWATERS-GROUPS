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
