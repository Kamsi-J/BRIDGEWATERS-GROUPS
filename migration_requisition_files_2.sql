-- Five more requisition files: Inventory, Electrical, Other Maintenance, Diesel, Adlac.
-- Run once in the Supabase SQL editor. Safe to run again (it skips files that already exist).
-- Needs migration_requisition_files.sql to have been run first (it creates the table).

INSERT INTO public.requisition_files (name, sort_order, active) VALUES
  ('Inventory',         18, true),
  ('Electrical',        19, true),
  ('Other Maintenance', 20, true),
  ('Diesel',            21, true),
  ('Adlac',             22, true)
ON CONFLICT (name) DO UPDATE SET active = true;

-- Check: should list all 22 files in order
SELECT sort_order, name, active FROM public.requisition_files ORDER BY sort_order;
