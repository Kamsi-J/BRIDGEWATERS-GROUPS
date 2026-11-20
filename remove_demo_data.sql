-- ============================================================
-- Removes ONLY the demo rows created by seed_demo_data.sql
-- (every demo id starts with 'dddddddd-'). Real data is untouched.
-- ============================================================
DELETE FROM public.requisitions WHERE id::text LIKE 'dddddddd-%';
DELETE FROM public.events       WHERE id::text LIKE 'dddddddd-%';

SELECT (SELECT count(*) FROM public.events)       AS events_left,
       (SELECT count(*) FROM public.requisitions) AS requisitions_left;
-- Note: requisition numbers continue from where the demo left off (the counter
-- is not reset). To restart at 1 once the table is empty:
--   ALTER SEQUENCE public.requisition_number_seq RESTART WITH 1;
