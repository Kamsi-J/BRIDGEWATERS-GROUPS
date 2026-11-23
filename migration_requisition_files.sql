-- Requisition files: storekeepers raise each requisition under one of the 17 files
-- (Kitchen Hotel, Kitchen Store, ... Ticket Paper). Run once in the Supabase SQL editor.
-- Run migration_md_workflow.sql first.

ALTER TABLE public.requisitions ADD COLUMN IF NOT EXISTS file     TEXT;
-- Requisitions raised in the same sitting share a batch_id so they can be shown as linked
ALTER TABLE public.requisitions ADD COLUMN IF NOT EXISTS batch_id TEXT;

CREATE INDEX IF NOT EXISTS requisitions_file_idx ON public.requisitions (file);

-- The list of files itself, so it lives in the database and can be changed without touching the app
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
