
create table public.support_requests (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  customer_email text not null,
  customer_phone text not null,
  subject text not null,
  message text not null,
  status text not null default 'new',
  admin_note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint support_requests_name_check
    check (char_length(btrim(customer_name)) between 1 and 120),
  constraint support_requests_email_check
    check (char_length(customer_email) between 3 and 254
      and customer_email ~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'),
  constraint support_requests_phone_check
    check (char_length(btrim(customer_phone)) between 1 and 40),
  constraint support_requests_subject_check
    check (char_length(btrim(subject)) between 1 and 200),
  constraint support_requests_message_check
    check (char_length(btrim(message)) between 1 and 10000),
  constraint support_requests_status_check
    check (status in ('new','in_progress','resolved','closed')),
  constraint support_requests_note_check
    check (char_length(admin_note) <= 10000)
);

create index support_requests_status_idx on public.support_requests (status);
create index support_requests_customer_email_idx on public.support_requests (customer_email);
create index support_requests_created_at_idx on public.support_requests (created_at desc);

create function private.prepare_support_request()
returns trigger
language plpgsql security invoker
set search_path = ''
as $function$
begin
  if tg_op = 'INSERT' then
    new.customer_name := btrim(new.customer_name);
    new.customer_email := lower(btrim(new.customer_email));
    new.customer_phone := btrim(new.customer_phone);
    new.subject := btrim(new.subject);
    new.message := btrim(new.message);
    new.created_at := clock_timestamp();
    new.updated_at := new.created_at;
  else
    new.updated_at := clock_timestamp();
  end if;
  return new;
end
$function$;

revoke all on function private.prepare_support_request()
  from public, anon, authenticated, service_role;

create trigger support_requests_prepare
before insert or update on public.support_requests
for each row execute function private.prepare_support_request();

alter table public.support_requests enable row level security;

create policy support_requests_public_insert
on public.support_requests for insert to anon, authenticated
with check (status = 'new' and admin_note = '');

create policy support_requests_admin_read
on public.support_requests for select to authenticated
using ((select private.is_admin()));

create policy support_requests_admin_update
on public.support_requests for update to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy support_requests_admin_delete
on public.support_requests for delete to authenticated
using ((select private.is_admin()));

revoke all on table public.support_requests from public, anon, authenticated;
grant insert (customer_name, customer_email, customer_phone, subject, message)
  on public.support_requests to anon, authenticated;
grant select on public.support_requests to authenticated;
grant update (status, admin_note) on public.support_requests to authenticated;
grant delete on public.support_requests to authenticated;

comment on table public.support_requests is
  'Public contact-form submissions. Contact details are supplied by the submitter. Only existing allowlisted admins can read or manage requests.';
comment on column public.support_requests.admin_note is
  'Internal admin note. Never returned to public visitors or non-admin customers.';

notify pgrst, 'reload schema';

