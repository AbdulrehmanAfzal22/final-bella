
alter table public.support_requests
  add column user_id uuid,
  add constraint support_requests_user_id_fkey
    foreign key (user_id) references auth.users(id) on delete set null;

create index support_requests_user_id_idx
  on public.support_requests (user_id);

comment on column public.support_requests.user_id is
  'Account that submitted the request, assigned from auth.uid() by the support trigger. Nullable for guest and legacy requests; clients cannot assign a different account.';

create or replace function private.prepare_support_request()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
begin
  if tg_op = 'INSERT' then
    if new.user_id is not null and new.user_id is distinct from v_user_id then
      raise exception 'Support requests can only be assigned to the signed-in account.'
        using errcode = '42501';
    end if;

    new.user_id := v_user_id;
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

alter policy support_requests_public_insert
  on public.support_requests
  to anon, authenticated
  with check (
    status = 'new'
    and admin_note = ''
    and admin_reply = ''
    and user_id is not distinct from (select auth.uid())
  );

create or replace function private.get_my_support_replies()
returns table (
  id uuid,
  subject text,
  message text,
  status text,
  admin_reply text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_email text;
begin
  if v_user_id is null then
    raise exception 'Authentication required.' using errcode = '42501';
  end if;

  select case
    when u.email_confirmed_at is not null then lower(btrim(u.email))
    else null
  end
  into v_email
  from auth.users as u
  where u.id = v_user_id;

  if not found then
    return;
  end if;

  return query
    select
      r.id,
      r.subject,
      r.message,
      r.status,
      r.admin_reply,
      r.created_at,
      r.updated_at
    from public.support_requests as r
    where (
      r.user_id = v_user_id
      or (
        r.user_id is null
        and v_email is not null
        and v_email <> ''
        and r.customer_email = v_email
      )
    )
    and btrim(r.admin_reply) <> ''
    order by r.updated_at desc, r.id desc;
end
$function$;

comment on function private.get_my_support_replies() is
  'Read-only support replies for the account recorded in user_id. Guest and legacy rows without user_id use the caller current confirmed email from auth.users. Internal notes and contact details are excluded.';

comment on function public.get_my_support_replies() is
  'No-argument customer reply RPC. Returns nonblank replies for requests owned by the signed-in account, with confirmed-email matching for guest and legacy requests only.';

notify pgrst, 'reload schema';

