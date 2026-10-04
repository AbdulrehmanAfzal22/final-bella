
create function private.ensure_customer_profile()
returns setof public.profiles
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_metadata jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication required.' using errcode = '42501';
  end if;

  select u.raw_user_meta_data into v_metadata
  from auth.users as u
  where u.id = v_user_id;
  if not found then
    raise exception 'Signed-in account not found.' using errcode = '42501';
  end if;

  insert into public.profiles (id, full_name)
  values (
    v_user_id,
    left(coalesce(v_metadata ->> 'full_name', ''), 150)
  )
  on conflict (id) do nothing;

  return query
  select p.*
  from public.profiles as p
  where p.id = v_user_id;

  if not found then
    raise exception 'Customer profile is unavailable.' using errcode = '42501';
  end if;
end;
$function$;

revoke execute on function private.ensure_customer_profile()
from public, anon, authenticated, service_role;
grant execute on function private.ensure_customer_profile() to authenticated;

comment on function private.ensure_customer_profile() is
'Ensures only auth.uid() has a profile, after checking the current auth.users record exists. Existing profiles are returned without updates. A missing profile uses the same full_name initialization as the existing signup trigger. Metadata is used only as display text, never for ownership or privileges. Does not create carts, wishlists, users or memberships.';

create function public.ensure_customer_profile()
returns setof public.profiles
language sql
volatile
security invoker
set search_path = ''
as $function$
  select p.id, p.full_name, p.created_at, p.updated_at
  from private.ensure_customer_profile() as p;
$function$;

revoke execute on function public.ensure_customer_profile()
from public, anon, authenticated, service_role;
grant execute on function public.ensure_customer_profile() to authenticated;

comment on function public.ensure_customer_profile() is
'No-argument authenticated API endpoint returning exactly the caller profile. Creates only a missing profile through the guarded private helper; existing profile values and timestamps remain unchanged.';

notify pgrst, 'reload schema';

