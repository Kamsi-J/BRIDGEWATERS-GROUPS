-- ============================================================
-- WIPES ALL event bookings and requisitions (demo AND test entries).
-- Staff accounts (profiles) and properties are NOT touched.
-- Run once, before staff start entering real data. Cannot be undone.
-- ============================================================
DELETE FROM public.requisitions;
DELETE FROM public.events;

-- Restart requisition numbering at 1
ALTER SEQUENCE public.requisition_number_seq RESTART WITH 1;

SELECT (SELECT count(*) FROM public.events)       AS events_left,
       (SELECT count(*) FROM public.requisitions) AS requisitions_left;
