-- Phase 1 — AI improvement data: pseudonymous id + query indexes.
--
-- Adds the pseudonymous export identifier and the indexes that dataset export
-- and product queries filter on. No data is rewritten here; legacy rows keep
-- their null user_id_hash (they are ineligible for export anyway).

alter table public.ai_rewrite_events
  add column if not exists user_id_hash text;

-- HMAC pseudonym used by every export (never the real user_id).
create index if not exists ai_rewrite_events_user_id_hash_idx
  on public.ai_rewrite_events (user_id_hash);

-- Export eligibility + scope filtering. dataset_eligible is a partial index
-- because the vast majority of rows are ineligible (metadata only).
create index if not exists ai_rewrite_events_dataset_eligible_idx
  on public.ai_rewrite_events (dataset_eligible)
  where dataset_eligible;

create index if not exists ai_rewrite_events_data_use_scope_idx
  on public.ai_rewrite_events (data_use_scope);

create index if not exists ai_rewrite_events_consent_version_idx
  on public.ai_rewrite_events (consent_version);

-- Selected candidate (feedback). Partial: only rows with a recorded selection.
create index if not exists ai_rewrite_events_selected_index_idx
  on public.ai_rewrite_events (selected_index)
  where selected_index is not null;

-- task_type is the command_key, which lives in the metadata payload.
create index if not exists ai_rewrite_events_command_key_idx
  on public.ai_rewrite_events ((payload ->> 'command_key'));
