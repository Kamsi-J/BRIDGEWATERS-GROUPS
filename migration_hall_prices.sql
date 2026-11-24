-- ============================================================
-- Standard hall prices + requisition locations
-- Paste into: Supabase Dashboard > SQL Editor > New Query > Run
-- Safe to run more than once.
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
