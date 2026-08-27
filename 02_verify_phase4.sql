-- ============================================================================
-- supabase/release/phase4/02_verify_phase4.sql
-- PHASE 4.2 — POST-DEPLOYMENT VERIFICATION (READ-ONLY, NO SIDE EFFECTS)
--
-- Run this AFTER 01_phase4_guard_checks.sql. Every query below only reads
-- from information_schema / pg_catalog — nothing is created, altered, or
-- disabled. In particular this NEVER turns RLS off, even to "check" it.
-- ============================================================================

-- A. TABLE EXISTS -------------------------------------------------------------
select 'A. guard_checks table exists' as check_name,
       case when exists(select 1 from information_schema.tables where table_schema='public' and table_name='guard_checks')
            then 'OK' else 'FAIL' end as status;

-- B. COLUMNS --------------------------------------------------------------------
-- Expected: id, school_id, student_id, checked_by, method, result, created_at
select 'B. column: ' || expected.col as check_name,
       case when c.column_name is not null then 'OK' else 'FAIL' end as status,
       c.data_type
from (values ('id'),('school_id'),('student_id'),('checked_by'),('method'),('result'),('created_at')) as expected(col)
left join information_schema.columns c
  on c.table_schema = 'public' and c.table_name = 'guard_checks' and c.column_name = expected.col
order by expected.col;

-- C. ROW LEVEL SECURITY ENABLED ---------------------------------------------
select 'C. RLS enabled on guard_checks' as check_name,
       case when relrowsecurity then 'OK' else 'FAIL' end as status
from pg_class
where relname = 'guard_checks' and relnamespace = 'public'::regnamespace;

-- D. POLICIES: exactly SELECT + INSERT present, UPDATE + DELETE absent -----
select
  'D. policy coverage' as check_name,
  cmd as postgres_command,
  count(*) as policy_count,
  array_agg(policyname) as policy_names,
  case
    when cmd in ('r','a') and count(*) >= 1 then 'OK (present, as expected)'
    when cmd in ('w','d') and count(*) = 0 then 'OK (absent, as expected — append-only)'
    when cmd in ('w','d') and count(*) > 0 then 'FAIL — an UPDATE/DELETE policy exists, this should be append-only'
    else 'FAIL — expected policy missing'
  end as status
from pg_policies
where schemaname = 'public' and tablename = 'guard_checks'
group by cmd
union all
-- surfaces the case where SELECT or INSERT has ZERO policies (the group-by
-- above would simply omit that row otherwise, which looks like success)
select 'D. policy coverage', missing.cmd, 0, array[]::text[], 'FAIL — no policy at all for this command'
from (values ('SELECT'),('INSERT')) as missing(cmd)
where not exists (
  select 1 from pg_policies
  where schemaname='public' and tablename='guard_checks'
    and cmd = case missing.cmd when 'SELECT' then 'r' when 'INSERT' then 'a' end
);

-- E. INDEXES ------------------------------------------------------------------
select 'E. index: ' || expected.idx as check_name,
       case when i.indexname is not null then 'OK' else 'FAIL' end as status
from (values ('ix_guard_checks_school_time'),('ix_guard_checks_guard_time')) as expected(idx)
left join pg_indexes i on i.schemaname = 'public' and i.indexname = expected.idx
order by expected.idx;

-- F. FOREIGN KEYS ---------------------------------------------------------------
select
  'F. foreign key: ' || kcu.column_name || ' -> ' || ccu.table_name || '.' || ccu.column_name as check_name,
  'OK' as status
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu on kcu.constraint_name = tc.constraint_name
join information_schema.constraint_column_usage ccu on ccu.constraint_name = tc.constraint_name
where tc.table_schema = 'public' and tc.table_name = 'guard_checks' and tc.constraint_type = 'FOREIGN KEY'
order by kcu.column_name;
-- Expect exactly 3 rows: school_id->schools.id, student_id->students.id, checked_by->profiles.id.
-- If fewer rows appear, a foreign key is missing — that IS a FAIL even
-- though this query can only report "OK" per found row (compare the row
-- count you see against the 3 expected above).

-- G. SECURITY EXPECTATIONS (textual introspection of policy definitions) -----
-- Confirms the INSERT policy's WITH CHECK clause actually references
-- auth.uid() and the school-scoping function — a light-touch textual check,
-- not a substitute for the live RLS test plan in 06_rls_test_plan.md.
select
  'G. INSERT policy references auth.uid()' as check_name,
  case when with_check ilike '%auth.uid()%' then 'OK' else 'FAIL' end as status
from pg_policies
where schemaname = 'public' and tablename = 'guard_checks' and policyname = 'p_guard_checks_insert'
union all
select
  'G. INSERT policy references fn_is_admin_or_guard (school isolation)',
  case when with_check ilike '%fn_is_admin_or_guard%' then 'OK' else 'FAIL' end
from pg_policies
where schemaname = 'public' and tablename = 'guard_checks' and policyname = 'p_guard_checks_insert'
union all
select
  'G. SELECT policy references fn_has_role (school isolation)',
  case when qual ilike '%fn_has_role%' then 'OK' else 'FAIL' end
from pg_policies
where schemaname = 'public' and tablename = 'guard_checks' and policyname = 'p_guard_checks_staff_read';

-- ============================================================================
-- READ THE RESULTS: every row across A-G should say OK. Any FAIL means the
-- deployment did not complete as expected — do not proceed to test data or
-- the frontend until every check above passes.
-- For a REAL confirmation that isolation and permissions work end-to-end
-- (not just "the policy text looks right"), run the live tests in
-- 06_rls_test_plan.md with two actual Guard accounts.
-- ============================================================================
