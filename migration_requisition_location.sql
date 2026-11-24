-- ============================================================
-- Requisition location: stamped by the database, not the browser
-- Paste into Supabase > SQL Editor > Run. Safe to run more than once.
-- ============================================================

-- From now on, every new requisition gets the location of the staff member who
-- raised it, set by the database itself, so it can never be left out.
--   * Storekeeper, banqueting manager etc.: always their profile location
--     (anything the browser sends is ignored).
--   * Admin: keeps the location she picked in the form; if she picked none,
--     her own profile location is used.
CREATE OR REPLACE FUNCTION public.set_req_location()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE prof_prop TEXT; prof_role TEXT;
BEGIN
  SELECT property_id, role INTO prof_prop, prof_role FROM public.profiles WHERE id = NEW.raised_by;
  IF prof_role IS DISTINCT FROM 'admin' AND prof_prop IS NOT NULL THEN
    NEW.property_id := prof_prop;
  ELSIF NEW.property_id IS NULL THEN
    NEW.property_id := prof_prop;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS requisitions_set_location ON public.requisitions;
CREATE TRIGGER requisitions_set_location BEFORE INSERT ON public.requisitions
  FOR EACH ROW EXECUTE FUNCTION public.set_req_location();

-- Back-fill: copy the location from the raiser's profile onto old requisitions
-- that have none. Run this again after you set locations on staff profiles.
UPDATE public.requisitions r
   SET property_id = p.property_id
  FROM public.profiles p
 WHERE r.property_id IS NULL AND r.raised_by = p.id AND p.property_id IS NOT NULL;

-- What is still unlabelled, by who raised it
SELECT coalesce(r.raised_by_name, p.full_name, 'Unknown') AS raised_by,
       p.role, p.property_id AS profile_location, count(*) AS requisitions_without_location
  FROM public.requisitions r
  LEFT JOIN public.profiles p ON p.id = r.raised_by
 WHERE r.property_id IS NULL
 GROUP BY 1, 2, 3
 ORDER BY 4 DESC;
