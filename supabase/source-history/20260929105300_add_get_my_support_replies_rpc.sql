
create function private.get_my_support_replies()
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

  select lower(btrim(u.email))
  into v_email
  from auth.users as u
  where u.id = v_user_id
    and u.email_confirmed_at is not null;

  if v_email is null or v_email = '' then
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
    where r.customer_email = v_email
      and btrim(r.admin_reply) <> ''
    order by r.updated_at desc, r.id desc;
end
$function$;

revoke all on function private.get_my_support_replies()
  from public, anon, authenticated, service_role;
grant execute on function private.get_my_support_replies() to authenticated;

comment on function private.get_my_support_replies() is
  'Read-only support reply projection for the caller authenticated by auth.uid(). Matches the current confirmed email from auth.users, never a client-supplied email or user_metadata. Excludes internal notes and contact details.';

create function public.get_my_support_replies()
returns table (
  id uuid,
  subject text,
  message text,
  status text,
  admin_reply text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select r.id, r.subject, r.message, r.status, r.admin_reply, r.created_at, r.updated_at
  from private.get_my_support_replies() as r;
$function$;

revoke all on function public.get_my_support_replies()
  from public, anon, authenticated, service_role;
grant execute on function public.get_my_support_replies() to authenticated;

comment on function public.get_my_support_replies() is
  'No-argument customer reply RPC. Returns only nonblank replies addressed to the signed-in account current confirmed email, newest first. Internal admin notes are never returned.';

notify pgrst, 'reload schema';

