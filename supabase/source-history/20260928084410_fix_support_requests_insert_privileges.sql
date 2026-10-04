
-- Expand existing support-only INSERT grants to table-level INSERT.
-- RLS still restricts every submission to status=new and an empty admin_note.
alter table public.support_requests enable row level security;
grant insert on table public.support_requests to anon, authenticated;
notify pgrst, 'reload schema';

