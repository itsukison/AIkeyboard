-- Records where a button came from, so analytics can tell an onboarding-built
-- button apart from one the user wrote later. `builtin_key` cannot: it is null
-- for both, and the two predict retention very differently.
--
-- Additive and nullable. Existing rows keep NULL and the client infers the same
-- value it inferred before this column existed (builtin_key present => builtin,
-- otherwise user_authored), so nothing needs backfilling for correctness.

alter table public.user_prompts
  add column if not exists origin text;

alter table public.user_prompts
  drop constraint if exists user_prompts_origin_check;

alter table public.user_prompts
  add constraint user_prompts_origin_check
  check (origin is null or origin in (
    'builtin',
    'onboarding_builder',
    'onboarding_preset',
    'user_authored'
  ));

-- Rows that predate the column but are unambiguous: a seeded built-in.
update public.user_prompts
set origin = 'builtin'
where origin is null
  and builtin_key is not null;
