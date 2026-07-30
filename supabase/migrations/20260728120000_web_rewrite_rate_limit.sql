-- Per-IP daily rate limiting for the unauthenticated `web-rewrite` edge
-- function, which backs the free browser tools on keigobutton.com.
--
-- Mirrors the `preset_gen_usage` design deliberately: a new table plus two
-- SECURITY DEFINER helpers, RLS-enabled with no policies so only the service
-- role (which bypasses RLS) can reach it. Nothing here references or alters
-- existing tables, so it cannot affect app users or the rest of the schema.
--
-- Difference from preset_gen_usage: the bump function returns the running
-- COUNT rather than a boolean, because the web tool shows the visitor how many
-- free conversions remain and swaps in the App Store CTA when it hits zero.

create table if not exists public.web_rewrite_usage (
  ip_hash text not null,
  window_start timestamptz not null,
  count integer not null default 0,
  primary key (ip_hash, window_start)
);

alter table public.web_rewrite_usage enable row level security;

-- Atomically increment the per-IP counter for the current day window and
-- return the new count. The limit itself lives in the edge function, so the cap
-- can be tuned by redeploying that function without a migration.
create or replace function public.bump_web_rewrite_usage(
  p_ip_hash text,
  p_window_start timestamptz
)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  new_count integer;
begin
  insert into public.web_rewrite_usage (ip_hash, window_start, count)
  values (p_ip_hash, p_window_start, 1)
  on conflict (ip_hash, window_start)
  do update set count = public.web_rewrite_usage.count + 1
  returning count into new_count;
  return new_count;
end;
$$;

revoke execute on function public.bump_web_rewrite_usage(text, timestamptz)
  from public, anon, authenticated;

-- Best-effort GC; schedule via pg_cron alongside the other retention jobs.
create or replace function public.delete_old_web_rewrite_usage(retain_days integer default 7)
returns void
language sql
security definer
set search_path to 'public'
as $$
  delete from public.web_rewrite_usage
  where window_start < now() - make_interval(days => retain_days);
$$;

revoke execute on function public.delete_old_web_rewrite_usage(integer)
  from public, anon, authenticated;
