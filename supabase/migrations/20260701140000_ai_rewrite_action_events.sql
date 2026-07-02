-- Append-only log of user actions on a rewrite result (beyond the accepted
-- candidate, which lives on ai_rewrite_events.selected_index). Enriches the
-- preference signal: `regenerated` = the whole batch was unsatisfactory,
-- `dismissed` = all candidates rejected. regeneration_count is derived by
-- counting `regenerated` rows per event_id at export time.
--
-- event_id is a logical reference to ai_rewrite_events.id (no FK): the event
-- row is inserted fire-and-forget after the response, so an action can race
-- ahead of it — a hard FK would drop the action rather than record it.
create table if not exists public.ai_rewrite_action_events (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null,
  user_id uuid not null,
  user_id_hash text,
  action text not null
    check (action in ('selected', 'inserted', 'copied', 'dismissed', 'regenerated')),
  selected_index integer,
  latency_ms integer,
  created_at timestamptz not null default now()
);

create index if not exists ai_rewrite_action_events_event_id_idx
  on public.ai_rewrite_action_events (event_id);
create index if not exists ai_rewrite_action_events_action_idx
  on public.ai_rewrite_action_events (action);
create index if not exists ai_rewrite_action_events_created_at_idx
  on public.ai_rewrite_action_events (created_at);

alter table public.ai_rewrite_action_events enable row level security;

revoke all on public.ai_rewrite_action_events from anon, authenticated;
grant select, insert, delete on public.ai_rewrite_action_events to service_role;

-- Same 30-day retention posture as the events themselves.
create or replace function public.delete_ai_rewrite_action_events_older_than(
  p_retention_days integer
)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_deleted integer;
begin
  if p_retention_days is null or p_retention_days < 1 then
    return 0;
  end if;

  delete from public.ai_rewrite_action_events
  where created_at < now() - make_interval(days => p_retention_days);

  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke execute on function public.delete_ai_rewrite_action_events_older_than(integer)
  from anon, authenticated;
grant execute on function public.delete_ai_rewrite_action_events_older_than(integer)
  to service_role;
