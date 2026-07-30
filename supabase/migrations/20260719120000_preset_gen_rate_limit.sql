-- Per-IP hourly rate limiting for the unauthenticated `generate-prompt-preset`
-- edge function. Fully isolated: a new table + two SECURITY DEFINER helpers,
-- RLS-enabled with no policies so only the service role (which bypasses RLS)
-- can touch it. Nothing here references or alters existing tables, so it has no
-- effect on existing users or the rest of the schema.

create table if not exists public.preset_gen_usage (
  ip_hash text not null,
  window_start timestamptz not null,
  count integer not null default 0,
  primary key (ip_hash, window_start)
);

alter table public.preset_gen_usage enable row level security;

-- Atomically increment the per-IP counter for the current hour window and
-- report whether the caller is still under the limit.
create or replace function public.bump_preset_gen_usage(
  p_ip_hash text,
  p_window_start timestamptz,
  p_limit integer
)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  new_count integer;
begin
  insert into public.preset_gen_usage (ip_hash, window_start, count)
  values (p_ip_hash, p_window_start, 1)
  on conflict (ip_hash, window_start)
  do update set count = public.preset_gen_usage.count + 1
  returning count into new_count;
  return new_count <= p_limit;
end;
$$;

revoke execute on function public.bump_preset_gen_usage(text, timestamptz, integer)
  from public, anon, authenticated;

-- Best-effort GC; schedule via pg_cron alongside the other retention jobs.
create or replace function public.delete_old_preset_gen_usage(retain_hours integer default 48)
returns void
language sql
security definer
set search_path to 'public'
as $$
  delete from public.preset_gen_usage
  where window_start < now() - make_interval(hours => retain_hours);
$$;

revoke execute on function public.delete_old_preset_gen_usage(integer)
  from public, anon, authenticated;
