-- ============================================================
-- Event bookings belong to a branch (property)
-- Paste into Supabase > SQL Editor > Run. Safe to run more than once.
--
-- Rules after this runs:
--   * Every booking is stamped with the property of its hall, by the database
--     itself (whatever the browser sends is ignored).
--   * Banqueting managers and BDMs only see, and can only book, halls in their
--     own branch. Oakland Hotel and Oakland Amusement Park count as ONE branch.
--   * Admin and MD see every branch (the app gives them a filter).
--   * Cashier and storekeeper see no events at all.
-- ============================================================

-- 1. The branch column
ALTER TABLE public.events ADD COLUMN IF NOT EXISTS property_id TEXT;

-- 2. Which property each hall belongs to (mirrors HALLS in events.html)
CREATE OR REPLACE FUNCTION public.hall_property(h TEXT) RETURNS TEXT
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE h
    WHEN 'william'     THEN 'bw_enugu'
    WHEN 'seraphina'   THEN 'bw_enugu'
    WHEN 'small_hall'  THEN 'bw_enugu'
    WHEN 'restaurant'  THEN 'bw_enugu'
    WHEN 'abuja_hall'  THEN 'bw_hotel'
    WHEN 'anambra'     THEN 'oak_enugu'
    WHEN 'enugu_hall'  THEN 'oak_enugu'
    WHEN 'board_room'  THEN 'oak_enugu'
    WHEN 'lounge'      THEN 'oak_enugu'
    WHEN 'delta'       THEN 'oak_park'
    WHEN 'pool'        THEN 'oak_park'
    WHEN 'conference'  THEN 'oak_park'   -- retired hall, old bookings only
    WHEN 'placia_hall' THEN 'placia'
  END
$$;

-- 3. Branches that share one team: both Oakland properties are one branch
CREATE OR REPLACE FUNCTION public.branch_group(p TEXT) RETURNS TEXT
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p IN ('oak_enugu','oak_park') THEN 'oakland' ELSE p END
$$;

-- 4. Back-fill the bookings that already exist
UPDATE public.events SET property_id = public.hall_property(hall_id) WHERE property_id IS NULL;
ALTER TABLE public.events ALTER COLUMN property_id SET NOT NULL;
CREATE INDEX IF NOT EXISTS events_property_date_idx ON public.events (property_id, date);

-- 5. New and moved bookings always take the branch of their hall
CREATE OR REPLACE FUNCTION public.set_event_property() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  NEW.property_id := public.hall_property(NEW.hall_id);
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS events_set_property ON public.events;
CREATE TRIGGER events_set_property BEFORE INSERT OR UPDATE OF hall_id ON public.events
  FOR EACH ROW EXECUTE FUNCTION public.set_event_property();

-- 6. Who may see / book a branch's events (reads the caller's profile)
CREATE OR REPLACE FUNCTION public.can_see_event(p_property TEXT) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles pr
     WHERE pr.id = auth.uid()
       AND ( pr.role IN ('admin','md')
          OR ( pr.role IN ('banqueting_manager','bdm')
               AND pr.property_id IS NOT NULL
               AND public.branch_group(pr.property_id) = public.branch_group(p_property) ) )
  )
$$;

CREATE OR REPLACE FUNCTION public.can_book_event(p_property TEXT) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles pr
     WHERE pr.id = auth.uid()
       AND pr.role IN ('banqueting_manager','bdm')
       AND pr.property_id IS NOT NULL
       AND public.branch_group(pr.property_id) = public.branch_group(p_property)
  )
$$;

-- 7. Replace the "everyone sees everything" rules
DROP POLICY IF EXISTS "events_read_all" ON public.events;
DROP POLICY IF EXISTS "events_read_by_branch" ON public.events;
CREATE POLICY "events_read_by_branch" ON public.events
  FOR SELECT TO authenticated USING (public.can_see_event(property_id));

DROP POLICY IF EXISTS "events_insert_booking_roles" ON public.events;
DROP POLICY IF EXISTS "events_insert_own_branch" ON public.events;
CREATE POLICY "events_insert_own_branch" ON public.events
  FOR INSERT TO authenticated WITH CHECK (public.can_book_event(property_id));
-- (events_delete_own and the device_gate rule are left as they are)

-- ── CHECKS (read-only) ───────────────────────────────────────
-- Bookings per branch
SELECT property_id, count(*) AS bookings FROM public.events GROUP BY 1 ORDER BY 1;

-- Booking staff with NO branch on their profile: they will see no events and
-- cannot book until you set their location (Staff page, or profiles.property_id).
SELECT full_name, role, email FROM public.profiles
 WHERE role IN ('banqueting_manager','bdm') AND property_id IS NULL;
