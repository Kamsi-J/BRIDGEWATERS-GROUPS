-- ============================================================
-- BRIDGE WATERS GROUP — Supabase Schema Setup
-- Paste this into: Dashboard > SQL Editor > New Query
-- Project: https://supabase.com/dashboard/project/brkzsxqqihbpnrsohhij
-- ============================================================

-- ── 1. PROFILES ──────────────────────────────────────────────
-- Extends auth.users with role information for each staff member
CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  full_name   TEXT NOT NULL DEFAULT '',
  role        TEXT NOT NULL DEFAULT 'admin'
              CHECK (role IN ('banqueting_manager', 'bdm', 'admin', 'md')),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE  public.profiles        IS 'Staff profiles with role-based access';
COMMENT ON COLUMN public.profiles.role   IS 'banqueting_manager | bdm | admin | md';

-- ── 2. EVENTS ────────────────────────────────────────────────
-- Hall bookings and event records across all venues
CREATE TABLE IF NOT EXISTS public.events (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name        TEXT NOT NULL,
  client      TEXT NOT NULL,
  date        DATE NOT NULL,
  hall_id     TEXT NOT NULL
              CHECK (hall_id IN ('grand','crystal','confA','confB','board','garden')),
  guests      INTEGER CHECK (guests IS NULL OR guests > 0),
  amount      NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (amount >= 0),
  notes       TEXT DEFAULT '',
  booked_by   UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.events IS 'Hall bookings — Banqueting Manager and BDM can create';

-- ── 3. ROW LEVEL SECURITY ─────────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events   ENABLE ROW LEVEL SECURITY;

-- Profiles: all authenticated staff can read
DROP POLICY IF EXISTS "profiles_read_all"    ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_own"  ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own"  ON public.profiles;

CREATE POLICY "profiles_read_all"   ON public.profiles
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE TO authenticated USING (auth.uid() = id);

-- Events: all authenticated staff can view
DROP POLICY IF EXISTS "events_read_all"            ON public.events;
DROP POLICY IF EXISTS "events_insert_booking_roles" ON public.events;
DROP POLICY IF EXISTS "events_delete_own"          ON public.events;

CREATE POLICY "events_read_all" ON public.events
  FOR SELECT TO authenticated USING (true);

-- Only Banqueting Manager and BDM can book events
CREATE POLICY "events_insert_booking_roles" ON public.events
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
        AND role IN ('banqueting_manager', 'bdm')
    )
  );

-- Booker can delete their own bookings
CREATE POLICY "events_delete_own" ON public.events
  FOR DELETE TO authenticated
  USING (booked_by = auth.uid());

-- ── 4. AUTO-CREATE PROFILE ON SIGNUP ─────────────────────────
-- Trigger auto-creates a profile row when a new auth user is created.
-- Pass 'full_name' and 'role' in user_metadata when creating the user.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'admin')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── 5. CREATING STAFF ACCOUNTS ───────────────────────────────
-- Go to: Dashboard > Authentication > Users > "Invite user"
-- Set email and a temporary password.
-- Then update their profile role:
--
-- UPDATE public.profiles
-- SET role = 'banqueting_manager', full_name = 'Jane Okonkwo'
-- WHERE id = '<user-uuid-from-auth-users>';
--
-- Roles available:
--   banqueting_manager  — Can view + book events
--   bdm                 — Can view + book events
--   admin               — View only (all events)
--   md                  — View only (all events + revenue)

SELECT 'Bridge Waters schema setup complete ✓' AS status;
