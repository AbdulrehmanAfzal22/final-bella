
create function private.get_customer_support_sender()
returns table (
  customer_name text,
  customer_email text,
  customer_phone text
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_auth_phone text;
  v_profile_name text;
  v_saved_name text;
  v_saved_phone text;
begin
  if v_user_id is null then
    raise exception 'Authentication required.' using errcode = '42501';
  end if;

  select lower(btrim(u.email)),
    case when u.phone_confirmed_at is not null then nullif(btrim(u.phone), '') else null end
  into v_email, v_auth_phone
  from auth.users as u
  where u.id = v_user_id;

  if not found then
    raise exception 'Signed-in account not found.' using errcode = '42501';
  end if;
  if v_email is null or v_email = '' then
    raise exception 'An email account is required to contact support.' using errcode = '22023';
  end if;

  select nullif(btrim(p.full_name), '') into v_profile_name
  from public.profiles as p
  where p.id = v_user_id;

  select nullif(btrim(r.customer_name), ''),
         nullif(nullif(btrim(r.customer_phone), ''), 'Not provided')
  into v_saved_name, v_saved_phone
  from public.support_requests as r
  where r.user_id = v_user_id
  order by r.created_at desc, r.id desc
  limit 1;

  return query
  select left(coalesce(v_profile_name, v_saved_name, v_email), 120),
         v_email,
         coalesce(v_auth_phone, v_saved_phone, 'Not provided');
end;
$function$;

revoke execute on function private.get_customer_support_sender()
from public, anon, authenticated, service_role;
grant execute on function private.get_customer_support_sender() to authenticated;

comment on function private.get_customer_support_sender() is
'Support-only identity lookup for auth.uid(): current database login email, own profile or saved contact name, confirmed account phone or own saved support phone. The literal Not provided denotes an absent phone number; user-editable JWT claims and other accounts are never used.';

create function public.send_customer_support_message(p_message text)
returns uuid
language plpgsql
volatile
security invoker
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_message text := btrim(p_message);
  v_sender record;
  v_request_id uuid;
  v_conversation_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required.' using errcode = '42501';
  end if;
  if v_message is null or char_length(v_message) < 1 or char_length(v_message) > 10000 then
    raise exception 'Message must contain between 1 and 10000 characters.' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('maison-elan:customer-support-send:' || v_user_id::text, 0)
  );

  select s.* into v_sender from private.get_customer_support_sender() as s;

  v_request_id := public.submit_support_request(
    p_customer_email => v_sender.customer_email,
    p_customer_name => v_sender.customer_name,
    p_customer_phone => v_sender.customer_phone,
    p_message => v_message,
    p_subject => 'Customer Support'
  );

  select c.id into v_conversation_id
  from public.get_my_support_conversations() as c
  where lower(btrim(c.subject)) = 'customer support';

  if not found then
    raise exception 'Support conversation could not be retrieved.' using errcode = 'P0002';
  end if;

  return v_conversation_id;
end;
$function$;

revoke execute on function public.send_customer_support_message(text)
from public, anon, authenticated, service_role;
grant execute on function public.send_customer_support_message(text) to authenticated;

comment on function public.send_customer_support_message(text) is
'Signed-in message-only contact endpoint. Inserts a new request through submit_support_request with subject Customer Support and own server-resolved contact identity; repeated messages group into the same normalized-subject conversation. Returns its canonical UUID for get_my_support_messages(p_conversation_id). Never overwrites previous requests, replies, or notes.';

notify pgrst, 'reload schema';

