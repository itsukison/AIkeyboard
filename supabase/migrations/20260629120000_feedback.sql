create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  created_at timestamptz not null default now(),
  category text not null,
  message text not null,
  app_version text,
  user_email text
);

create index if not exists feedback_created_at_idx
  on public.feedback (created_at);

create index if not exists feedback_user_id_created_at_idx
  on public.feedback (user_id, created_at);

alter table public.feedback enable row level security;

-- All access goes through the submit-feedback Edge Function (service role).
-- Clients never read or write this table directly.
revoke all on public.feedback from anon, authenticated;
grant select, insert, update, delete on public.feedback to service_role;
