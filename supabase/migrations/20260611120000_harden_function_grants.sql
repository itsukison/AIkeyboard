-- Security hardening flagged by the Supabase database linter.
--
-- 1. `handle_new_user()` is a SECURITY DEFINER trigger function but is granted
--    EXECUTE to PUBLIC/anon/authenticated, so it is also callable as an RPC
--    (POST /rest/v1/rpc/handle_new_user) by unauthenticated clients. Triggers
--    fire regardless of EXECUTE grants, so revoking API access changes nothing
--    about sign-up while removing the RPC attack surface.
--    Linter: 0028 / 0029.
revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- 2. `touch_updated_at()` has a role-mutable search_path. Pin it so the
--    function always resolves objects against `public`.
--    Linter: 0011.
alter function public.touch_updated_at() set search_path = public;
