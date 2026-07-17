-- Allow `replace_failed`: the user tapped a candidate but the proxy-context
-- validation failed, so the replacement never happened. Without this signal a
-- user whose accept path always fails is indistinguishable from one who never
-- liked any candidate.
alter table public.ai_rewrite_action_events
  drop constraint ai_rewrite_action_events_action_check;

alter table public.ai_rewrite_action_events
  add constraint ai_rewrite_action_events_action_check
  check (action in ('selected', 'inserted', 'copied', 'dismissed', 'regenerated', 'replace_failed'));
