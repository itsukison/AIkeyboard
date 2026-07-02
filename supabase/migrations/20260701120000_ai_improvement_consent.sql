-- Phase 0 — AI improvement data: consent scaffolding + legacy privacy alignment.
--
-- Goal: make raw-text retention opt-in and fail-closed. This migration
--   1. adds a per-user consent record (default: no consent, scope 'none'),
--   2. adds governance columns to ai_rewrite_events so every row records the
--      scope it was captured under and whether it may be exported, and
--   3. PRUNES raw user text from all pre-existing (legacy) rows, which were
--      stored before any retention consent existed, and marks them ineligible.
--
-- Step 3 is DESTRUCTIVE and irreversible by design — it deletes raw input,
-- reply context, and candidate text from historical rows. If a raw backup is
-- wanted for any reason, it must be taken manually BEFORE running this
-- migration; we intentionally do not copy the raw text into a backup table,
-- since that would defeat the purpose.

-- 1. Per-user consent. Authoritative source of truth for retention decisions;
-- the edge function reads it server-side. Absent row == no consent.
create table if not exists public.user_ai_consent (
  user_id uuid primary key,
  ai_improvement_opt_in boolean not null default false,
  data_use_scope text not null default 'none'
    check (data_use_scope in (
      'none', 'internal_improvement', 'research_benchmark', 'commercial_dataset'
    )),
  raw_text_allowed boolean not null default false,
  consent_version text,
  consented_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.user_ai_consent enable row level security;

-- The container app (role: authenticated, user JWT) reads and sets its own
-- consent row. The edge function (service_role) reads it and bypasses RLS.
revoke all on public.user_ai_consent from anon, authenticated;
grant select, insert, update on public.user_ai_consent to authenticated;
grant select, insert, update, delete on public.user_ai_consent to service_role;

create policy "user_ai_consent_select_own" on public.user_ai_consent
  for select to authenticated using (auth.uid() = user_id);
create policy "user_ai_consent_insert_own" on public.user_ai_consent
  for insert to authenticated with check (auth.uid() = user_id);
create policy "user_ai_consent_update_own" on public.user_ai_consent
  for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 2. Governance columns on the event log. data_use_scope is the scope in
-- effect at capture time (consent can change later, but export eligibility must
-- reflect what the user agreed to when the row was written). dataset_eligible
-- gates every export view; it defaults false and fails closed.
alter table public.ai_rewrite_events
  add column if not exists data_use_scope text not null default 'none'
    check (data_use_scope in (
      'none', 'internal_improvement', 'research_benchmark', 'commercial_dataset'
    )),
  add column if not exists dataset_eligible boolean not null default false,
  add column if not exists consent_version text;

-- 3. Legacy privacy alignment. Every row written before this migration holds
-- raw text under only the "send to AI" consent, not a retention consent. Strip
-- the text-bearing keys, keep non-sensitive metadata (command_key, title,
-- locale, provider, lengths, counts, latency, language), and mark the rows
-- clearly unconsented + ineligible for any dataset export.
-- Guarded on the presence of a text key so the statement is idempotent and
-- never touches already-stripped or new metadata-only rows.
update public.ai_rewrite_events
set
  payload = payload - array['prompt', 'input', 'reply_to', 'candidates'],
  data_use_scope = 'none',
  dataset_eligible = false,
  consent_version = 'legacy_unconsented'
where payload ? 'input'
   or payload ? 'prompt'
   or payload ? 'reply_to'
   or payload ? 'candidates';
