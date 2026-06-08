create table if not exists public.ai_rewrite_usage_buckets (
  scope text not null,
  bucket text not null,
  used_units integer not null default 0,
  request_count integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (scope, bucket)
);

alter table public.ai_rewrite_usage_buckets enable row level security;

revoke all on public.ai_rewrite_usage_buckets from anon, authenticated;
grant select, insert, update on public.ai_rewrite_usage_buckets to service_role;

create or replace function public.reserve_ai_rewrite_usage(
  p_user_id text,
  p_units integer,
  p_day_bucket text,
  p_hour_bucket text,
  p_minute_bucket text,
  p_user_daily_unit_limit integer,
  p_user_hourly_request_limit integer,
  p_user_minute_request_limit integer,
  p_global_daily_unit_limit integer,
  p_global_minute_request_limit integer
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_day_scope text := 'user:' || p_user_id || ':day';
  v_user_hour_scope text := 'user:' || p_user_id || ':hour';
  v_user_minute_scope text := 'user:' || p_user_id || ':minute';
  v_global_day_scope text := 'global:day';
  v_global_minute_scope text := 'global:minute';
  v_user_day public.ai_rewrite_usage_buckets%rowtype;
  v_user_hour public.ai_rewrite_usage_buckets%rowtype;
  v_user_minute public.ai_rewrite_usage_buckets%rowtype;
  v_global_day public.ai_rewrite_usage_buckets%rowtype;
  v_global_minute public.ai_rewrite_usage_buckets%rowtype;
begin
  if p_user_id is null or length(p_user_id) = 0 or p_units < 1 then
    return jsonb_build_object(
      'allowed', false,
      'message', 'AIの利用制限を確認できませんでした。少し待ってからもう一度お試しください。'
    );
  end if;

  perform pg_advisory_xact_lock(hashtextextended('ai_rewrite_usage:global', 0));
  perform pg_advisory_xact_lock(hashtextextended('ai_rewrite_usage:user:' || p_user_id, 0));

  insert into public.ai_rewrite_usage_buckets (scope, bucket)
  values
    (v_user_day_scope, p_day_bucket),
    (v_user_hour_scope, p_hour_bucket),
    (v_user_minute_scope, p_minute_bucket),
    (v_global_day_scope, p_day_bucket),
    (v_global_minute_scope, p_minute_bucket)
  on conflict do nothing;

  select * into v_user_day
  from public.ai_rewrite_usage_buckets
  where scope = v_user_day_scope and bucket = p_day_bucket
  for update;

  select * into v_user_hour
  from public.ai_rewrite_usage_buckets
  where scope = v_user_hour_scope and bucket = p_hour_bucket
  for update;

  select * into v_user_minute
  from public.ai_rewrite_usage_buckets
  where scope = v_user_minute_scope and bucket = p_minute_bucket
  for update;

  select * into v_global_day
  from public.ai_rewrite_usage_buckets
  where scope = v_global_day_scope and bucket = p_day_bucket
  for update;

  select * into v_global_minute
  from public.ai_rewrite_usage_buckets
  where scope = v_global_minute_scope and bucket = p_minute_bucket
  for update;

  if v_user_day.used_units + p_units > p_user_daily_unit_limit then
    return jsonb_build_object('allowed', false, 'message', '本日のAI利用上限に達しました。明日もう一度お試しください。');
  end if;

  if v_user_hour.request_count + 1 > p_user_hourly_request_limit then
    return jsonb_build_object('allowed', false, 'message', '短時間のAI利用が多すぎます。少し待ってからもう一度お試しください。');
  end if;

  if v_user_minute.request_count + 1 > p_user_minute_request_limit then
    return jsonb_build_object('allowed', false, 'message', '短時間のAI利用が多すぎます。少し待ってからもう一度お試しください。');
  end if;

  if v_global_day.used_units + p_units > p_global_daily_unit_limit then
    return jsonb_build_object('allowed', false, 'message', '本日のAI利用上限に達しました。時間をおいてもう一度お試しください。');
  end if;

  if v_global_minute.request_count + 1 > p_global_minute_request_limit then
    return jsonb_build_object('allowed', false, 'message', 'AIが混み合っています。少し待ってからもう一度お試しください。');
  end if;

  update public.ai_rewrite_usage_buckets
  set used_units = used_units + p_units,
      request_count = request_count + 1,
      updated_at = now()
  where (scope, bucket) in (
    (v_user_day_scope, p_day_bucket),
    (v_user_hour_scope, p_hour_bucket),
    (v_user_minute_scope, p_minute_bucket),
    (v_global_day_scope, p_day_bucket),
    (v_global_minute_scope, p_minute_bucket)
  );

  return jsonb_build_object('allowed', true, 'message', '');
end;
$$;

revoke execute on function public.reserve_ai_rewrite_usage(
  text,
  integer,
  text,
  text,
  text,
  integer,
  integer,
  integer,
  integer,
  integer
) from anon, authenticated;

grant execute on function public.reserve_ai_rewrite_usage(
  text,
  integer,
  text,
  text,
  text,
  integer,
  integer,
  integer,
  integer,
  integer
) to service_role;
