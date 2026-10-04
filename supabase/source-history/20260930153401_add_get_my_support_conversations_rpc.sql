
create function private.get_my_support_conversations()
returns table (
  id uuid,
  subject text,
  status text,
  message text,
  admin_reply text,
  created_at timestamptz,
  updated_at timestamptz,
  message_count bigint,
  messages jsonb
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
  end into v_email
  from auth.users as u
  where u.id = v_user_id;

  if not found then
    return;
  end if;

  return query
  with owned_requests as (
    select r.*, lower(btrim(r.subject)) as subject_key
    from public.support_requests as r
    where r.user_id = v_user_id
      or (
        r.user_id is null
        and v_email is not null
        and v_email <> ''
        and r.customer_email = v_email
      )
  ),
  conversation_summary as (
    select
      r.subject_key,
      (array_agg(r.id order by r.created_at asc, r.id asc))[1] as root_request_id,
      (array_agg(r.subject order by r.created_at asc, r.id asc))[1] as display_subject,
      (array_agg(r.status order by r.updated_at desc, r.id desc))[1] as latest_status,
      (array_agg(r.message order by r.created_at desc, r.id desc))[1] as latest_customer_message,
      (array_agg(r.admin_reply order by r.updated_at desc, r.id desc)
        filter (where btrim(r.admin_reply) <> ''))[1] as latest_admin_reply,
      min(r.created_at) as first_created_at,
      max(r.updated_at) as last_updated_at
    from owned_requests as r
    group by r.subject_key
  ),
  stored_messages as (
    select
      r.subject_key,
      r.id as message_id,
      r.id as request_id,
      'customer'::text as sender,
      r.message as message_text,
      r.created_at as message_timestamp,
      'request_created_at'::text as time_source,
      0 as sender_order
    from owned_requests as r

    union all

    select
      r.subject_key,
      md5('maison-elan:support-request:admin-reply:' || r.id::text)::uuid,
      r.id,
      'admin'::text,
      r.admin_reply,
      r.updated_at,
      'request_updated_at_not_original_reply_timestamp'::text,
      1
    from owned_requests as r
    where btrim(r.admin_reply) <> ''
  ),
  conversation_messages as (
    select
      m.subject_key,
      count(*) as stored_message_count,
      jsonb_agg(
        jsonb_build_object(
          'id', m.message_id,
          'support_request_id', m.request_id,
          'sender_type', m.sender,
          'message', m.message_text,
          'created_at', m.message_timestamp,
          'timestamp_source', m.time_source
        )
        order by m.message_timestamp asc, m.sender_order asc, m.message_id asc
      ) as stored_message_list
    from stored_messages as m
    group by m.subject_key
  )
  select
    c.root_request_id,
    c.display_subject,
    c.latest_status,
    c.latest_customer_message,
    coalesce(c.latest_admin_reply, ''),
    c.first_created_at,
    c.last_updated_at,
    m.stored_message_count,
    m.stored_message_list
  from conversation_summary as c
  join conversation_messages as m on m.subject_key = c.subject_key
  order by c.last_updated_at desc, c.root_request_id desc;
end
$function$;

revoke all on function private.get_my_support_conversations()
  from public, anon, authenticated, service_role;
grant execute on function private.get_my_support_conversations() to authenticated;

create function public.get_my_support_conversations()
returns table (
  id uuid,
  subject text,
  status text,
  message text,
  admin_reply text,
  created_at timestamptz,
  updated_at timestamptz,
  message_count bigint,
  messages jsonb
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select
    c.id, c.subject, c.status, c.message, c.admin_reply,
    c.created_at, c.updated_at, c.message_count, c.messages
  from private.get_my_support_conversations() as c;
$function$;

revoke all on function public.get_my_support_conversations()
  from public, anon, authenticated, service_role;
grant execute on function public.get_my_support_conversations() to authenticated;

comment on function private.get_my_support_conversations() is
  'Read-only customer conversation projection. Filters by auth.uid(), with current confirmed email fallback only for guest/legacy requests without user_id, then groups trimmed case-insensitive subjects for this caller. Returns a stable earliest request UUID, latest request status/customer message, latest nonblank saved admin reply, and the available message list. Never returns internal admin notes or other accounts requests. Saved reply timestamps use request updated_at and are marked in each message timestamp_source; overwritten reply history was not stored.';

comment on function public.get_my_support_conversations() is
  'No-argument customer conversation RPC. Returns id, subject, status, message, admin_reply, created_at, updated_at, message_count and messages. Unanswered requests are included. Only authenticated callers can execute; all identity checks run in the private helper.';

notify pgrst, 'reload schema';

