create or replace function public.delete_old_ai_rewrite_usage_buckets(
  p_minute_hour_retention_hours integer,
  p_day_retention_days integer
)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_deleted integer;
begin
  delete from public.ai_rewrite_usage_buckets
  where (
    scope like '%:minute' or scope like '%:hour'
  )
  and updated_at < now() - make_interval(hours => greatest(p_minute_hour_retention_hours, 1));

  get diagnostics v_deleted = row_count;

  delete from public.ai_rewrite_usage_buckets
  where scope like '%:day'
  and updated_at < now() - make_interval(days => greatest(p_day_retention_days, 1));

  return v_deleted;
end;
$$;

revoke execute on function public.delete_old_ai_rewrite_usage_buckets(integer, integer)
  from anon, authenticated;
grant execute on function public.delete_old_ai_rewrite_usage_buckets(integer, integer)
  to service_role;
