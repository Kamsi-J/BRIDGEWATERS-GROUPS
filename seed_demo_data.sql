-- ============================================================
-- BRIDGE WATERS: demo data for the MD review
-- Supabase Dashboard > SQL Editor > New query > paste > Run.
-- Safe to run more than once (rows have fixed ids and are skipped if present).
-- Every demo row id starts with 'dddddddd-', so remove_demo_data.sql can delete
-- exactly these rows and nothing else.
-- Dates are relative to today, so the dashboard always looks current.
-- Run migration_md_workflow.sql FIRST (it adds edit_log and req_number).
-- ============================================================

-- 1. The hall_id check in the original schema lists old hall ids that the app
--    no longer uses. It would reject these rows and also any booking made in
--    the app. Replace it with the five halls the app actually has.
ALTER TABLE public.events DROP CONSTRAINT IF EXISTS events_hall_id_check;
ALTER TABLE public.events ADD CONSTRAINT events_hall_id_check
  CHECK (hall_id IN ('william','seraphina','anambra','delta','conference'));

-- 2. Events: 40 bookings from a year ago to five weeks ahead (booked_by is left
--    empty because the bookings were not made by a real login).
INSERT INTO public.events (id, name, client, date, hall_id, guests, amount, notes)
VALUES
  ('dddddddd-0001-4000-8000-000000000001', 'Eze-Nnamdi Wedding Reception', 'Eze family', current_date + (-335), 'delta', 480, 5400000, ''),
  ('dddddddd-0001-4000-8000-000000000002', 'ECCIMA Trade Summit', 'ECCIMA', current_date + (-318), 'conference', 90, 1350000, ''),
  ('dddddddd-0001-4000-8000-000000000003', 'Access Bank Awards Night', 'Access Bank', current_date + (-301), 'william', 310, 4200000, ''),
  ('dddddddd-0001-4000-8000-000000000004', 'ICAN Members Dinner', 'ICAN', current_date + (-286), 'anambra', 204, 2175000, ''),
  ('dddddddd-0001-4000-8000-000000000005', 'Dangote Training Week', 'Dangote Group', current_date + (-270), 'seraphina', 148, 2600000, ''),
  ('dddddddd-0001-4000-8000-000000000006', 'Okafor Family Thanksgiving', 'Okafor family', current_date + (-254), 'delta', 360, 3900000, ''),
  ('dddddddd-0001-4000-8000-000000000007', 'First Bank Town Hall', 'First Bank', current_date + (-240), 'william', 280, 3800000, ''),
  ('dddddddd-0001-4000-8000-000000000008', 'UNN Alumni Planning Meeting', 'UNN Alumni Association', current_date + (-222), 'conference', 60, 950000, ''),
  ('dddddddd-0001-4000-8000-000000000009', 'Adeyemi-Bello Wedding', 'Adeyemi family', current_date + (-205), 'delta', 520, 6100000, ''),
  ('dddddddd-0001-4000-8000-000000000010', 'Church Anniversary Gala', 'Holy Trinity Parish', current_date + (-190), 'anambra', 230, 2900000, ''),
  ('dddddddd-0001-4000-8000-000000000011', 'Zenith Bank Customer Forum', 'Zenith Bank', current_date + (-176), 'william', 330, 4600000, ''),
  ('dddddddd-0001-4000-8000-000000000012', 'NNPC Staff Retreat', 'NNPC', current_date + (-160), 'seraphina', 148, 3120000, ''),
  ('dddddddd-0001-4000-8000-000000000013', 'Enugu Fashion Week', 'Enugu Fashion Council', current_date + (-147), 'delta', 440, 5750000, ''),
  ('dddddddd-0001-4000-8000-000000000014', 'Pharmacists Council Workshop', 'PCN', current_date + (-133), 'conference', 85, 1420000, ''),
  ('dddddddd-0001-4000-8000-000000000015', 'Wema Bank Long Service Awards', 'Wema Bank', current_date + (-121), 'william', 360, 4950000, ''),
  ('dddddddd-0001-4000-8000-000000000016', 'Ibeto Group Dealers Dinner', 'Ibeto Group', current_date + (-108), 'anambra', 250, 3350000, ''),
  ('dddddddd-0001-4000-8000-000000000017', 'Nwosu-Okeke Wedding', 'Nwosu family', current_date + (-96), 'delta', 510, 6400000, ''),
  ('dddddddd-0001-4000-8000-000000000018', 'Glo Sales Conference', 'Globacom', current_date + (-84), 'seraphina', 160, 2850000, ''),
  ('dddddddd-0001-4000-8000-000000000019', 'Diamond Bank Alumni Reunion', 'Diamond Bank Alumni', current_date + (-72), 'william', 290, 3900000, ''),
  ('dddddddd-0001-4000-8000-000000000020', 'Teachers Union Seminar', 'NUT Enugu', current_date + (-61), 'conference', 75, 1150000, ''),
  ('dddddddd-0001-4000-8000-000000000021', 'Anene Family Funeral Reception', 'Anene family', current_date + (-49), 'delta', 300, 3200000, ''),
  ('dddddddd-0001-4000-8000-000000000022', 'Medical Doctors Association Dinner', 'NMA Enugu', current_date + (-41), 'anambra', 215, 3050000, ''),
  ('dddddddd-0001-4000-8000-000000000023', 'Stanbic IBTC Investors Forum', 'Stanbic IBTC', current_date + (-33), 'william', 350, 5300000, ''),
  ('dddddddd-0001-4000-8000-000000000024', 'Total Energies Safety Week', 'Total Energies', current_date + (-27), 'seraphina', 130, 2400000, ''),
  ('dddddddd-0001-4000-8000-000000000025', 'Umeh-Ibe Wedding Reception', 'Umeh family', current_date + (-19), 'delta', 495, 6200000, ''),
  ('dddddddd-0001-4000-8000-000000000026', 'Fidelity Bank Staff Awards', 'Fidelity Bank', current_date + (-12), 'william', 340, 4700000, ''),
  ('dddddddd-0001-4000-8000-000000000027', 'Law Society Annual Dinner', 'NBA Enugu Branch', current_date + (-9), 'anambra', 240, 3400000, ''),
  ('dddddddd-0001-4000-8000-000000000028', 'NIPR Media Briefing', 'NIPR', current_date + (-5), 'conference', 80, 1300000, ''),
  ('dddddddd-0001-4000-8000-000000000029', 'Shell Contractors Briefing', 'Shell Nigeria', current_date + (-2), 'seraphina', 150, 2750000, ''),
  ('dddddddd-0001-4000-8000-000000000030', 'Zenith Bank Regional AGM', 'Zenith Bank', current_date + (0), 'william', 312, 4850000, 'Setup from 6am. Stage and projector in the main hall.'),
  ('dddddddd-0001-4000-8000-000000000031', 'Obi-Chukwu Engagement Party', 'Obi family', current_date + (0), 'delta', 280, 3600000, ''),
  ('dddddddd-0001-4000-8000-000000000032', 'Okonkwo-Eze Wedding Reception', 'Okonkwo family', current_date + (2), 'delta', 487, 6200000, 'Florals and linen arranged through Banqueting.'),
  ('dddddddd-0001-4000-8000-000000000033', 'Julius Berger Management Retreat', 'Julius Berger Nigeria', current_date + (4), 'seraphina', 140, 3120000, ''),
  ('dddddddd-0001-4000-8000-000000000034', 'ICAN Annual Conference', 'ICAN', current_date + (7), 'william', 380, 5600000, ''),
  ('dddddddd-0001-4000-8000-000000000035', 'Heritage Bank Awards', 'Heritage Bank', current_date + (9), 'anambra', 210, 2950000, ''),
  ('dddddddd-0001-4000-8000-000000000036', 'Enugu Chamber Summit', 'ECCIMA', current_date + (13), 'conference', 96, 1480000, ''),
  ('dddddddd-0001-4000-8000-000000000037', 'Ezeani-Onwudiwe Wedding', 'Ezeani family', current_date + (16), 'delta', 470, 5900000, ''),
  ('dddddddd-0001-4000-8000-000000000038', 'Corporate Christmas Gala Dinner', 'Bridge Waters Events', current_date + (21), 'william', 400, 7200000, 'Corporate tables sold in blocks of ten.'),
  ('dddddddd-0001-4000-8000-000000000039', 'Airtel Year-End Review', 'Airtel Nigeria', current_date + (26), 'seraphina', 140, 2900000, ''),
  ('dddddddd-0001-4000-8000-000000000040', 'New Year Thanksgiving Service', 'Grace Chapel', current_date + (33), 'delta', 420, 4100000, '')
ON CONFLICT (id) DO NOTHING;

-- 3. Requisitions: 12 requests across every status. req_number is assigned by
--    the trigger, oldest first.
INSERT INTO public.requisitions
  (id, purpose, items, total_amount, vendor_name, vendor_bank, vendor_account_no, vendor_account_name,
   notes, status, raised_by_name, raised_by_role, admin_notes, md_query, rejection_reason,
   approved_at, rejected_at, paid_at, edit_log, created_at, updated_at)
VALUES
  ('dddddddd-0002-4000-8000-000000000001', 'Staff uniforms for front desk and banqueting', '[{"description": "Uniform set, front desk", "qty": 20, "unit_cost": 18500, "total": 370000}, {"description": "Uniform set, banqueting", "qty": 20, "unit_cost": 18500, "total": 370000}]'::jsonb, 740000, 'Atelier Ada Tailors', 'Zenith Bank', '2087341956', 'Atelier Ada Tailors', '', 'paid', 'Emeka Obi', 'storekeeper', '', '', null, now() - interval '97 days', null, now() - interval '92 days', '[]'::jsonb, now() - interval '100 days', now() - interval '92 days'),
  ('dddddddd-0002-4000-8000-000000000002', 'Deep cleaning and fumigation, Abuja hotel', '[{"description": "Fumigation, all floors", "qty": 1, "unit_cost": 180000, "total": 180000}, {"description": "Deep clean, public areas and halls", "qty": 1, "unit_cost": 300000, "total": 300000}]'::jsonb, 480000, 'PestAway Services', 'GTBank', '0451876320', 'PestAway Services Ltd', 'Scheduled for the low-occupancy weekend.', 'paid', 'Chika Nwosu', 'banqueting_manager', '', '', null, now() - interval '70 days', null, now() - interval '66 days', '[]'::jsonb, now() - interval '75 days', now() - interval '66 days'),
  ('dddddddd-0002-4000-8000-000000000003', 'Bar stock for ICAN members dinner', '[{"description": "Assorted soft drinks, carton", "qty": 60, "unit_cost": 6500, "total": 390000}, {"description": "Bottled water, carton", "qty": 80, "unit_cost": 2800, "total": 224000}, {"description": "House wine, case of 12", "qty": 12, "unit_cost": 53000, "total": 636000}]'::jsonb, 1250000, 'Eastern Beverages Ltd', 'Access Bank', '0123984576', 'Eastern Beverages Ltd', '', 'paid', 'Emeka Obi', 'storekeeper', '', '', null, now() - interval '41 days', null, now() - interval '38 days', '[]'::jsonb, now() - interval '44 days', now() - interval '38 days'),
  ('dddddddd-0002-4000-8000-000000000004', 'Sound system hire for NNPC staff retreat', '[{"description": "PA system and two microphones, per day", "qty": 2, "unit_cost": 120000, "total": 240000}, {"description": "Sound engineer, per day", "qty": 2, "unit_cost": 55000, "total": 110000}]'::jsonb, 350000, 'Tonic Audio Visual', 'UBA', '2145009871', 'Tonic Audio Visual Ltd', '', 'paid', 'Chika Nwosu', 'banqueting_manager', '', '', null, now() - interval '21 days', null, now() - interval '18 days', '[]'::jsonb, now() - interval '24 days', now() - interval '18 days'),
  ('dddddddd-0002-4000-8000-000000000005', 'Generator diesel, 2,000 litres', '[{"description": "Diesel, per litre", "qty": 2000, "unit_cost": 740, "total": 1480000}]'::jsonb, 1480000, 'Total Energies Enugu Depot', 'First Bank', '3098712245', 'Total Energies Marketing Nigeria', 'Monthly supply.', 'paid', 'Emeka Obi', 'storekeeper', '', '', null, now() - interval '13 days', null, now() - interval '11 days', '[]'::jsonb, now() - interval '15 days', now() - interval '11 days'),
  ('dddddddd-0002-4000-8000-000000000006', 'Table linen replacement', '[{"description": "Tablecloth, 10 ft round", "qty": 30, "unit_cost": 6500, "total": 195000}, {"description": "Napkins", "qty": 200, "unit_cost": 350, "total": 70000}]'::jsonb, 265000, 'Linen House', 'Fidelity Bank', '5120398847', 'Linen House Enterprises', '', 'paid', 'Chika Nwosu', 'banqueting_manager', '', '', null, now() - interval '6 days', null, now() - interval '3 days', '[]'::jsonb, now() - interval '9 days', now() - interval '3 days'),
  ('dddddddd-0002-4000-8000-000000000007', 'Imported chandelier for Seraphina Hall', '[{"description": "Crystal chandelier, 24-arm", "qty": 1, "unit_cost": 1850000, "total": 1850000}]'::jsonb, 1850000, 'Lumiere Interiors', 'Stanbic IBTC', '0098123764', 'Lumiere Interiors Ltd', 'Replaces the damaged fitting.', 'rejected', 'Chika Nwosu', 'banqueting_manager', '', '', 'Outside the approved capex budget for this quarter. Resubmit with a repair quote.', null, now() - interval '5 days', null, '[]'::jsonb, now() - interval '6 days', now() - interval '5 days'),
  ('dddddddd-0002-4000-8000-000000000008', 'Food items for Zenith Bank regional AGM dinner', '[{"description": "Parboiled rice, 50kg bag", "qty": 4, "unit_cost": 92500, "total": 370000}, {"description": "Frozen chicken, carton", "qty": 12, "unit_cost": 48700, "total": 584400}, {"description": "Palm oil, 25 litres", "qty": 3, "unit_cost": 61000, "total": 183000}]'::jsonb, 1137400, 'Fresh Mart Supplies Ltd', 'Access Bank', '0123456789', 'Fresh Mart Supplies Ltd', 'Delivery needed by 6am on the day of the event.', 'pending', 'Chika Nwosu', 'banqueting_manager', '', '', null, null, null, null, '[]'::jsonb, now() - interval '5 days', now() - interval '4 days'),
  ('dddddddd-0002-4000-8000-000000000009', 'Kitchen gas refill, 6 cylinders', '[{"description": "Gas refill, 50kg cylinder", "qty": 6, "unit_cost": 98000, "total": 588000}]'::jsonb, 588000, 'Enugu Gas Depot', 'GTBank', '0176540982', 'Enugu Gas Depot', '', 'queried', 'Emeka Obi', 'storekeeper', '', 'Gas is up on last month. Can we get a second quote before approving?', null, null, null, null, '[]'::jsonb, now() - interval '3 days', now() - interval '2 days'),
  ('dddddddd-0002-4000-8000-000000000010', 'Floral arrangements for the Okonkwo-Eze wedding', '[{"description": "Table centrepiece", "qty": 20, "unit_cost": 18500, "total": 370000}, {"description": "Aisle arch with flowers", "qty": 1, "unit_cost": 145000, "total": 145000}]'::jsonb, 515000, 'Petal Studio Enugu', 'Zenith Bank', '1012348765', 'Petal Studio Enugu', 'Colour theme: ivory and gold.', 'approved', 'Chika Nwosu', 'banqueting_manager', '', '', null, now() - interval '1 days', null, null, jsonb_build_array(jsonb_build_object('at', to_jsonb(now() - interval '1 days'), 'by', 'Admin', 'role', 'admin', 'summary', jsonb_build_array('"Table centrepiece": qty 18 → 20','Total ₦478,000 → ₦515,000'))), now() - interval '2 days', now() - interval '1 days'),
  ('dddddddd-0002-4000-8000-000000000011', 'Cooking oil and seasoning restock', '[{"description": "Groundnut oil, 25 litres", "qty": 6, "unit_cost": 78000, "total": 468000}, {"description": "Seasoning, carton", "qty": 8, "unit_cost": 14500, "total": 116000}]'::jsonb, 584000, 'Mama Nkechi Provisions', 'Access Bank', '0765432109', 'Mama Nkechi Provisions', '', 'approved', 'Emeka Obi', 'storekeeper', '', '', null, now() - interval '0 days', null, null, jsonb_build_array(jsonb_build_object('at', to_jsonb(now() - interval '0 days'), 'by', 'Admin', 'role', 'admin', 'summary', jsonb_build_array('"Seasoning, carton": cost ₦16,000 → ₦14,500','Total ₦596,000 → ₦584,000'))), now() - interval '1 days', now() - interval '0 days'),
  ('dddddddd-0002-4000-8000-000000000012', 'Housekeeping consumables for November', '[{"description": "Industrial detergent, 20 litres", "qty": 20, "unit_cost": 5400, "total": 108000}, {"description": "Bin liners, roll of 50", "qty": 30, "unit_cost": 2800, "total": 84000}, {"description": "Toilet rolls, carton", "qty": 15, "unit_cost": 9500, "total": 142500}]'::jsonb, 334500, 'CleanCo Nigeria', 'Zenith Bank', '2034567891', 'CleanCo Nigeria Ltd', '', 'pending', 'Emeka Obi', 'storekeeper', '', '', null, null, null, null, '[]'::jsonb, now() - interval '1 days', now() - interval '0 days')
ON CONFLICT (id) DO NOTHING;

SELECT (SELECT count(*) FROM public.events        WHERE id::text LIKE 'dddddddd-%') AS demo_events,
       (SELECT count(*) FROM public.requisitions  WHERE id::text LIKE 'dddddddd-%') AS demo_requisitions;
