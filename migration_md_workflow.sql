-- ============================================================
-- BRIDGE WATERS — Requisition workflow + roles migration
-- Run in: Supabase Dashboard > SQL Editor > New Query
-- Safe to re-run. REVIEW the "existing policies" note at the bottom first.
-- ============================================================

-- ── 1. PROFILES: allow all six roles + columns the app already uses ──────
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('banqueting_manager','bdm','admin','md','storekeeper','cashier'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email       TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS property_id TEXT;

-- Helper: current user's role (SECURITY DEFINER avoids RLS recursion)
CREATE OR REPLACE FUNCTION public.my_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT role FROM public.profiles WHERE id = auth.uid() $$;

-- SECURITY FIX: the old "profiles_update_own" policy let any user change their
-- OWN role (e.g. promote themselves to md). Users may now edit their profile
-- but not their role; admins can manage every profile.
DROP POLICY IF EXISTS "profiles_update_own"   ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_admin" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_admin" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id AND role = public.my_role());
CREATE POLICY "profiles_update_admin" ON public.profiles FOR UPDATE TO authenticated
  USING (public.my_role() = 'admin') WITH CHECK (public.my_role() = 'admin');
CREATE POLICY "profiles_insert_admin" ON public.profiles FOR INSERT TO authenticated
  WITH CHECK (public.my_role() = 'admin');

-- ── 2. REQUISITIONS ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.requisitions (
  id                  UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  purpose             TEXT NOT NULL,
  items               JSONB NOT NULL DEFAULT '[]',
  total_amount        NUMERIC(15,2) NOT NULL DEFAULT 0,
  vendor_name         TEXT,
  vendor_bank         TEXT,
  vendor_account_no   TEXT,
  vendor_account_name TEXT,
  notes               TEXT DEFAULT '',
  status              TEXT NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending','approved','paid','rejected','queried')),
  raised_by           UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  raised_by_name      TEXT,
  raised_by_role      TEXT,
  admin_notes         TEXT DEFAULT '',
  md_query            TEXT DEFAULT '',
  rejection_reason    TEXT,
  approved_by UUID, approved_at TIMESTAMPTZ,
  rejected_by UUID, rejected_at TIMESTAMPTZ,
  paid_by     UUID, paid_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);
-- NEW: audit trail of every Admin / MD edit  [{at, by, role, summary:[...]}]
ALTER TABLE public.requisitions ADD COLUMN IF NOT EXISTS edit_log JSONB NOT NULL DEFAULT '[]';
-- in case the table already existed without these:
ALTER TABLE public.requisitions ADD COLUMN IF NOT EXISTS admin_notes      TEXT DEFAULT '';
ALTER TABLE public.requisitions ADD COLUMN IF NOT EXISTS md_query         TEXT DEFAULT '';
ALTER TABLE public.requisitions ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
ALTER TABLE public.requisitions DROP CONSTRAINT IF EXISTS requisitions_status_check;
ALTER TABLE public.requisitions ADD CONSTRAINT requisitions_status_check
  CHECK (status IN ('pending','approved','paid','rejected','queried'));

-- ── 2b. REQUISITION NUMBERS  (REQ-2026-0001, REQ-2026-0002, …) ───────────
CREATE SEQUENCE IF NOT EXISTS public.requisition_number_seq START 1;
ALTER TABLE public.requisitions ADD COLUMN IF NOT EXISTS req_number TEXT;

-- Number any existing requisitions, oldest first
DO $$
DECLARE rec RECORD;
BEGIN
  FOR rec IN SELECT id, created_at FROM public.requisitions
             WHERE req_number IS NULL ORDER BY created_at, id LOOP
    UPDATE public.requisitions
       SET req_number = 'REQ-' || to_char(rec.created_at, 'YYYY') || '-' ||
                        lpad(nextval('public.requisition_number_seq')::text, 4, '0')
     WHERE id = rec.id;
  END LOOP;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS requisitions_req_number_key ON public.requisitions (req_number);

-- Assign on insert; never let anyone change it afterwards
CREATE OR REPLACE FUNCTION public.set_req_number()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.req_number := 'REQ-' || to_char(COALESCE(NEW.created_at, NOW()), 'YYYY') || '-' ||
                      lpad(nextval('public.requisition_number_seq')::text, 4, '0');
  ELSE
    NEW.req_number := OLD.req_number;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS requisitions_set_number ON public.requisitions;
CREATE TRIGGER requisitions_set_number
  BEFORE INSERT OR UPDATE ON public.requisitions
  FOR EACH ROW EXECUTE FUNCTION public.set_req_number();

ALTER TABLE public.requisitions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "req_select"        ON public.requisitions;
DROP POLICY IF EXISTS "req_insert"        ON public.requisitions;
DROP POLICY IF EXISTS "req_update_review" ON public.requisitions;
DROP POLICY IF EXISTS "req_update_cashier" ON public.requisitions;
DROP POLICY IF EXISTS "req_delete_md"     ON public.requisitions;

-- Raisers see only their own; admin / md / cashier see everything
CREATE POLICY "req_select" ON public.requisitions FOR SELECT TO authenticated
  USING (public.my_role() IN ('admin','md','cashier') OR raised_by = auth.uid());

-- Only Banqueting Manager and Store Keeper raise requisitions, and only as themselves
CREATE POLICY "req_insert" ON public.requisitions FOR INSERT TO authenticated
  WITH CHECK (public.my_role() IN ('banqueting_manager','storekeeper') AND raised_by = auth.uid());

-- Admin and MD can edit / approve / reject / query
CREATE POLICY "req_update_review" ON public.requisitions FOR UPDATE TO authenticated
  USING (public.my_role() IN ('admin','md'))
  WITH CHECK (public.my_role() IN ('admin','md'));

-- Cashier can only move an approved requisition to paid
CREATE POLICY "req_update_cashier" ON public.requisitions FOR UPDATE TO authenticated
  USING (public.my_role() = 'cashier' AND status = 'approved')
  WITH CHECK (public.my_role() = 'cashier' AND status = 'paid');

-- Only MD can delete
CREATE POLICY "req_delete_md" ON public.requisitions FOR DELETE TO authenticated
  USING (public.my_role() = 'md');

-- NOTE: RLS policies are OR-ed. If the live database already has older,
-- looser policies on public.requisitions, they stay active next to these.
-- Check Dashboard > Authentication > Policies and drop any you don't want.

SELECT 'Requisition workflow migration complete ✓' AS status;
