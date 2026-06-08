create table if not exists public.ai_rewrite_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  created_at timestamptz not null default now(),
  payload jsonb not null,
  selected_index integer,
  selected_at timestamptz
);

create index if not exists ai_rewrite_events_created_at_idx
  on public.ai_rewrite_events (created_at);

create index if not exists ai_rewrite_events_user_id_created_at_idx
  on public.ai_rewrite_events (user_id, created_at);

alter table public.ai_rewrite_events enable row level security;

revoke all on public.ai_rewrite_events from anon, authenticated;
grant select, insert, update, delete on public.ai_rewrite_events to service_role;

create or replace function public.delete_ai_rewrite_events_older_than(
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

  delete from public.ai_rewrite_events
  where created_at < now() - make_interval(days => p_retention_days);

  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke execute on function public.delete_ai_rewrite_events_older_than(integer)
  from anon, authenticated;
grant execute on function public.delete_ai_rewrite_events_older_than(integer)
  to service_role;
