-- ============================================================================
-- supabase/release/phase4/01_phase4_guard_checks.sql
-- PHASE 4.2 — RELEASE VERSION of supabase/migrations/phase4_guard_checks.sql
--
-- This is the SAME schema and the SAME RLS logic already validated in
-- Phase 4 — nothing new was invented for this release. It is repackaged
-- here as a standalone, copy/paste-safe script for Supabase SQL Editor.
--
-- IDEMPOTENCY — read before running twice:
--   - CREATE TABLE ... IF NOT EXISTS: safe, but if guard_checks already
--     exists with a DIFFERENT structure than below, this will NOT fix or
--     alter it — it will silently do nothing to the table. Run
--     02_verify_phase4.sql afterward to confirm the actual structure
--     matches what's expected; do not assume success from "no error".
--   - CREATE INDEX ... IF NOT EXISTS: safe, Postgres supports this natively.
--   - CREATE POLICY has NO "IF NOT EXISTS" clause in PostgreSQL. Rather
--     than DROP an existing policy (forbidden by this release's
--     no-destructive-operations rule) and recreate it — which would also
--     briefly risk a policy-less window — each policy is wrapped in a
--     DO block that checks pg_policies first and only creates it if
--     missing. This makes the whole script safely re-runnable without any
--     DROP statement anywhere.
-- ============================================================================

create table if not exists guard_checks (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  student_id uuid references students(id) on delete set null, -- null when the token/search matched no one
  checked_by uuid not null references profiles(id),
  method text not null check (method in ('qr','manual')),
  result text not null check (result in ('AUTHORIZED','UNAUTHORIZED','ABSENT_INACTIVE','UNKNOWN_ERROR')),
  created_at timestamptz not null default now()
);

create index if not exists ix_guard_checks_school_time on guard_checks(school_id, created_at desc);
create index if not exists ix_guard_checks_guard_time on guard_checks(checked_by, created_at desc);

alter table guard_checks enable row level security; -- idempotent by nature, safe to re-run

-- ----------------------------------------------------------------------------
-- SELECT policy: staff (admin/guard/director) within the same school only.
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'guard_checks' and policyname = 'p_guard_checks_staff_read'
  ) then
    execute $sql$
      create policy p_guard_checks_staff_read on guard_checks for select using (
        fn_has_role(school_id, array['admin','guard','director']::app_role[])
      )
    $sql$;
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- INSERT policy: guard/admin only, and only ever logging themselves as
-- checked_by — a client cannot log a check "as" another guard.
-- ----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'guard_checks' and policyname = 'p_guard_checks_insert'
  ) then
    execute $sql$
      create policy p_guard_checks_insert on guard_checks for insert with check (
        checked_by = auth.uid() and fn_is_admin_or_guard(school_id)
      )
    $sql$;
  end if;
end $$;

-- No UPDATE/DELETE policy exists, and none is created here: append-only,
-- same philosophy as audit_logs. RLS defaults to DENY when no policy
-- matches a command, so UPDATE/DELETE are refused for every client role.

-- ============================================================================
-- END OF RELEASE FILE 01 — run 02_verify_phase4.sql next.
-- ============================================================================
