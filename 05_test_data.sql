-- ============================================================================
-- supabase/release/phase4/05_test_data.sql
-- PHASE 4.2 — TEST-ENVIRONMENT SEED DATA ONLY
--
-- DO NOT RUN THIS ON A PRODUCTION SCHOOL PROJECT. This is meant for a
-- disposable/test Supabase project (or a project you're fine adding two
-- fake schools to). Every row uses fixed, documented UUIDs so this script,
-- 06_rls_test_plan.md, and your manual testing all refer to the exact same
-- records — and so it's safe to re-run (ON CONFLICT DO NOTHING everywhere).
--
-- SCENARIO BUILT:
--   École Test A -> Élève Test A -> Badge A   (Guard A must see this)
--   École Test B -> Élève Test B -> Badge B   (Guard A must NOT see this)
--
-- WHY TWO PARTS:
--   PART 1 has no dependency on Supabase Auth — safe to run immediately.
--   PART 2 creates `profiles` rows, and profiles.id is a foreign key to
--   auth.users(id) (phase2_schema.sql). Per this release's rules, this
--   script does NOT create auth users. You must first create "Guard A" and
--   "Guard B" manually in Supabase Dashboard -> Authentication -> Users
--   (see README_PHASE4_DEPLOY.md step 4), copy their UUIDs, and paste them
--   into the two placeholders below before running PART 2.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- PART 1 — schools, academic years, classes, students, enrollments, badges.
-- No Auth dependency. Safe to run now.
-- ----------------------------------------------------------------------------

insert into schools (id, name) values
  ('a0000000-0000-4000-a000-000000000001', 'École Test A'),
  ('b0000000-0000-4000-b000-000000000001', 'École Test B')
on conflict (id) do nothing;

insert into academic_years (id, school_id, label, starts_on, ends_on, is_current) values
  ('a0000000-0000-4000-a000-000000000002', 'a0000000-0000-4000-a000-000000000001', '2026/2027', '2026-09-01', '2027-07-01', true),
  ('b0000000-0000-4000-b000-000000000002', 'b0000000-0000-4000-b000-000000000001', '2026/2027', '2026-09-01', '2027-07-01', true)
on conflict (id) do nothing;

insert into classes (id, school_id, academic_year_id, name, level) values
  ('a0000000-0000-4000-a000-000000000003', 'a0000000-0000-4000-a000-000000000001', 'a0000000-0000-4000-a000-000000000002', '6A-TEST', '6ème'),
  ('b0000000-0000-4000-b000-000000000003', 'b0000000-0000-4000-b000-000000000001', 'b0000000-0000-4000-b000-000000000002', '6A-TEST', '6ème')
on conflict (id) do nothing;

insert into students (id, school_id, student_number, full_name) values
  ('a0000000-0000-4000-a000-000000000004', 'a0000000-0000-4000-a000-000000000001', 'TEST-A-001', 'Élève Test A'),
  ('b0000000-0000-4000-b000-000000000004', 'b0000000-0000-4000-b000-000000000001', 'TEST-B-001', 'Élève Test B')
on conflict (id) do nothing;

insert into student_enrollments (id, student_id, school_id, academic_year_id, class_id, status) values
  ('a0000000-0000-4000-a000-000000000005', 'a0000000-0000-4000-a000-000000000004', 'a0000000-0000-4000-a000-000000000001', 'a0000000-0000-4000-a000-000000000002', 'a0000000-0000-4000-a000-000000000003', 'ACTIVE'),
  ('b0000000-0000-4000-b000-000000000005', 'b0000000-0000-4000-b000-000000000004', 'b0000000-0000-4000-b000-000000000001', 'b0000000-0000-4000-b000-000000000002', 'b0000000-0000-4000-b000-000000000003', 'ACTIVE')
on conflict (id) do nothing;

-- Fixed secure_token values so you can generate a physical/on-screen QR code
-- for each (any free QR generator, encode the token text exactly) to test
-- the Guard console's real camera scan end-to-end.
insert into student_badges (id, student_id, secure_token, status) values
  ('a0000000-0000-4000-a000-000000000006', 'a0000000-0000-4000-a000-000000000004', 'a0000000-0000-4000-a000-0000000000a1', 'ACTIVE'),
  ('b0000000-0000-4000-b000-000000000006', 'b0000000-0000-4000-b000-000000000004', 'b0000000-0000-4000-b000-0000000000b1', 'ACTIVE')
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
-- PART 2 — Guard accounts. REQUIRES MANUAL SUBSTITUTION.
--
-- Before running this part:
--   1. Supabase Dashboard -> Authentication -> Users -> Add user
--      Create two users (any email/password, e.g. guard-a-test@example.com).
--   2. Copy each user's UUID (shown in the Users table).
--   3. Replace REPLACE_WITH_GUARD_A_AUTH_UID and REPLACE_WITH_GUARD_B_AUTH_UID
--      below with those real UUIDs.
--   4. Only then run this part. Running it unmodified will fail with an
--      "invalid input syntax for type uuid" error — that is intentional,
--      it stops you from accidentally inserting garbage.
-- ----------------------------------------------------------------------------

insert into profiles (id, full_name) values
  ('REPLACE_WITH_GUARD_A_AUTH_UID'::uuid, 'Guard Test A'),
  ('REPLACE_WITH_GUARD_B_AUTH_UID'::uuid, 'Guard Test B')
on conflict (id) do nothing;

insert into user_roles (profile_id, school_id, role) values
  ('REPLACE_WITH_GUARD_A_AUTH_UID'::uuid, 'a0000000-0000-4000-a000-000000000001', 'guard'),
  ('REPLACE_WITH_GUARD_B_AUTH_UID'::uuid, 'b0000000-0000-4000-b000-000000000001', 'guard')
on conflict (profile_id, school_id, role) do nothing;

-- Optional (recommended for consistency with the schema's `guards` staff
-- directory, but NOT required for the RLS test itself — only user_roles is
-- read by fn_has_role()/fn_is_admin_or_guard()):
insert into guards (profile_id, school_id) values
  ('REPLACE_WITH_GUARD_A_AUTH_UID'::uuid, 'a0000000-0000-4000-a000-000000000001'),
  ('REPLACE_WITH_GUARD_B_AUTH_UID'::uuid, 'b0000000-0000-4000-b000-000000000001')
on conflict (profile_id, school_id) do nothing;

-- NOTE: this does NOT set up PIN/QR login (staff_pins, user_number,
-- login_qr_tokens from Phase 3.3) for these two test guards. To actually
-- log into the app as Guard A/B from a phone, additionally run (existing
-- Phase 3.3 functions, nothing new):
--   select fn_set_user_pin('REPLACE_WITH_GUARD_A_AUTH_UID'::uuid, '1357');
--   select fn_set_user_pin('REPLACE_WITH_GUARD_B_AUTH_UID'::uuid, '2468');
--   update profiles set user_number = '90001' where id = 'REPLACE_WITH_GUARD_A_AUTH_UID'::uuid;
--   update profiles set user_number = '90002' where id = 'REPLACE_WITH_GUARD_B_AUTH_UID'::uuid;
-- (avoid PINs like 1234/1111 — fn_set_user_pin rejects the weak-PIN list
-- from phase3_3_qr_manual_login.sql and will raise PIN_TOO_WEAK if you pick one)

-- ============================================================================
-- END OF TEST DATA — see 06_rls_test_plan.md for what to test with this data.
-- ============================================================================
