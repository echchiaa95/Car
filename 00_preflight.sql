-- ============================================================================
-- supabase/release/phase4/00_preflight.sql
-- PHASE 4.2 — PREFLIGHT CHECK (READ-ONLY, NO SIDE EFFECTS)
--
-- Purpose: confirm every dependency that 01_phase4_guard_checks.sql needs
-- already exists in THIS Supabase project, before running it.
-- This script contains NO CREATE / ALTER / INSERT / DROP of any kind — it
-- only reads from information_schema / pg_catalog. Safe to run any number
-- of times, on any environment, including production.
--
-- HOW TO USE
--   1. Paste this whole file into Supabase SQL Editor.
--   2. Run it.
--   3. Read the result grid: every row must show status = 'OK'.
--   4. If ANY row shows 'MISSING', STOP — do not run 01_phase4_guard_checks.sql
--      yet. That dependency comes from phase2_schema.sql or one of the
--      phase3_*.sql migrations, which must be applied first.
-- ============================================================================

select check_name, case when passed then 'OK' else 'MISSING' end as status, detail
from (
  select 'table: schools' as check_name,
         exists(select 1 from information_schema.tables where table_schema='public' and table_name='schools') as passed,
         'required as guard_checks.school_id foreign key target (phase2_schema.sql)' as detail
  union all
  select 'table: students',
         exists(select 1 from information_schema.tables where table_schema='public' and table_name='students'),
         'required as guard_checks.student_id foreign key target (phase2_schema.sql)'
  union all
  select 'table: student_badges',
         exists(select 1 from information_schema.tables where table_schema='public' and table_name='student_badges'),
         'required by the Guard console badge-scan lookup (modules/students.js), not by guard_checks itself'
  union all
  select 'table: student_enrollments',
         exists(select 1 from information_schema.tables where table_schema='public' and table_name='student_enrollments'),
         'required by the Guard console roster/class views (modules/students.js), not by guard_checks itself'
  union all
  select 'table: classes',
         exists(select 1 from information_schema.tables where table_schema='public' and table_name='classes'),
         'required by the Classes view (modules/students.js listClasses())'
  union all
  select 'table: academic_years',
         exists(select 1 from information_schema.tables where table_schema='public' and table_name='academic_years'),
         'required by the Classes view (current-year filter)'
  union all
  select 'table: profiles',
         exists(select 1 from information_schema.tables where table_schema='public' and table_name='profiles'),
         'required as guard_checks.checked_by foreign key target (phase2_schema.sql)'
  union all
  select 'table: user_roles',
         exists(select 1 from information_schema.tables where table_schema='public' and table_name='user_roles'),
         'required by fn_has_role()/fn_is_admin_or_guard() used in guard_checks RLS policies'
  union all
  select 'enum: app_role',
         exists(select 1 from pg_type where typname = 'app_role'),
         'required by fn_has_role()''s array[...]::app_role[] cast'
  union all
  select 'function: public.fn_has_role(uuid, app_role[])',
         exists(
           select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'fn_has_role'
         ),
         'used directly in guard_checks SELECT policy'
  union all
  select 'function: public.fn_is_admin_or_guard(uuid)',
         exists(
           select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'fn_is_admin_or_guard'
         ),
         'used directly in guard_checks INSERT policy'
  union all
  select 'schema: auth (Supabase Auth)',
         exists(select 1 from information_schema.schemata where schema_name = 'auth'),
         'auth.uid() must resolve — standard on every Supabase project, checked defensively'
) checks
order by (status <> 'OK') desc, check_name; -- surfaces any MISSING row first

-- ----------------------------------------------------------------------------
-- Informational only (NOT a pass/fail — both outcomes are fine):
-- tells you whether guard_checks already exists, so you know what to expect
-- from 01_phase4_guard_checks.sql (see its own idempotency notes).
-- ----------------------------------------------------------------------------
select
  'info: guard_checks table already present?' as check_name,
  case when exists(select 1 from information_schema.tables where table_schema='public' and table_name='guard_checks')
       then 'YES — 01 will skip table/index creation, only add any missing policy'
       else 'NO — 01 will create it fresh'
  end as status;
