
create function private.admin_get_support_inbox()
returns table (
  id uuid,
  user_id uuid,
  customer_name text,
  customer_email text,
  customer_phone text,
  subject text,
  status text,
  message text,
  admin_reply text,
  admin_note text,
  created_at timestamptz,
  updated_at timestamptz,
  conversation_id uuid,
  support_request_id uuid,
  conversation_count bigint,
  message_count bigint,
  conversations jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Admin access required.' using errcode = '42501';
  end if;

  return query
  with request_context as (
    select r.*,
      case when r.user_id is not null then 'user:' || r.user_id::text
           else 'guest:' || lower(btrim(r.customer_email)) end as customer_key,
      lower(btrim(r.subject)) as subject_key,
      nullif(lower(btrim(u.email)), '') as login_email,
      nullif(btrim(p.full_name), '') as profile_name
    from public.support_requests as r
    left join auth.users as u on u.id = r.user_id
    left join public.profiles as p on p.id = r.user_id
  ),
  customer_summary as (
    select r.customer_key,
      (array_agg(r.user_id order by r.created_at desc, r.id desc))[1] as owner_id,
      (array_agg(coalesce(r.profile_name, nullif(btrim(r.customer_name), ''),
                         r.login_email, r.customer_email)
        order by r.created_at desc, r.id desc))[1] as display_name,
      (array_agg(coalesce(r.login_email, lower(btrim(r.customer_email)))
        order by r.created_at desc, r.id desc))[1] as display_email,
      coalesce(
        (array_agg(r.customer_phone order by r.created_at desc, r.id desc)
          filter (where btrim(r.customer_phone) <> ''
                  and lower(btrim(r.customer_phone)) <> 'not provided'))[1],
        (array_agg(r.customer_phone order by r.created_at desc, r.id desc))[1]
      ) as display_phone,
      min(r.created_at) as first_created_at,
      max(r.updated_at) as last_updated_at
    from request_context as r
    group by r.customer_key
  ),
  conversation_summary as (
    select r.customer_key, r.subject_key,
      (array_agg(r.id order by r.created_at asc, r.id asc))[1] as root_request_id,
      (array_agg(r.id order by r.updated_at desc, r.id desc))[1] as latest_request_id,
      (array_agg(r.subject order by r.created_at asc, r.id asc))[1] as display_subject,
      (array_agg(r.status order by r.updated_at desc, r.id desc))[1] as latest_status,
      (array_agg(r.message order by r.created_at desc, r.id desc))[1] as latest_customer_message,
      coalesce((array_agg(r.admin_reply order by r.updated_at desc, r.id desc)
        filter (where btrim(r.admin_reply) <> ''))[1], '') as latest_admin_reply,
      (array_agg(r.admin_note order by r.updated_at desc, r.id desc))[1] as latest_admin_note,
      min(r.created_at) as first_created_at,
      max(r.updated_at) as last_updated_at,
      count(*) as request_count,
      count(*) + count(*) filter (where btrim(r.admin_reply) <> '') as stored_message_count
    from request_context as r
    group by r.customer_key, r.subject_key
  ),
  latest_conversation as (
    select distinct on (t.customer_key) t.*
    from conversation_summary as t
    order by t.customer_key, t.last_updated_at desc, t.root_request_id desc
  ),
  customer_conversations as (
    select t.customer_key,
      count(*) as thread_count,
      sum(t.stored_message_count)::bigint as stored_message_count,
      jsonb_agg(jsonb_build_object(
        'id', t.root_request_id,
        'conversation_id', t.root_request_id,
        'support_request_id', t.latest_request_id,
        'subject', t.display_subject,
        'status', t.latest_status,
        'message', t.latest_customer_message,
        'admin_reply', t.latest_admin_reply,
        'admin_note', t.latest_admin_note,
        'created_at', t.first_created_at,
        'updated_at', t.last_updated_at,
        'request_count', t.request_count,
        'message_count', t.stored_message_count
      ) order by t.last_updated_at desc, t.root_request_id desc) as thread_list
    from conversation_summary as t
    group by t.customer_key
  )
  select t.root_request_id, c.owner_id,
    c.display_name, c.display_email, c.display_phone,
    t.display_subject, t.latest_status, t.latest_customer_message,
    t.latest_admin_reply, t.latest_admin_note,
    c.first_created_at, c.last_updated_at,
    t.root_request_id, t.latest_request_id,
    a.thread_count, a.stored_message_count, a.thread_list
  from customer_summary as c
  join latest_conversation as t on t.customer_key = c.customer_key
  join customer_conversations as a on a.customer_key = c.customer_key
  order by c.last_updated_at desc, t.root_request_id desc;
end;
$function$;

revoke execute on function private.admin_get_support_inbox()
from public, anon, authenticated, service_role;
grant execute on function private.admin_get_support_inbox() to authenticated;

comment on function private.admin_get_support_inbox() is
'Admin-only read projection: one inbox row per signed-in account UUID or separate guest email group, with nested normalized-subject conversations. Uses auth.users only to resolve the login email for support request owners. id/conversation_id identify the newest active subject root, compatible with admin_get_support_messages; support_request_id identifies that thread latest updated request. message_count counts customer requests plus current nonblank saved replies, not overwritten reply history or unread messages. Does not merge guest submissions into authenticated accounts.';

create function public.admin_get_support_inbox()
returns table (
  id uuid,
  user_id uuid,
  customer_name text,
  customer_email text,
  customer_phone text,
  subject text,
  status text,
  message text,
  admin_reply text,
  admin_note text,
  created_at timestamptz,
  updated_at timestamptz,
  conversation_id uuid,
  support_request_id uuid,
  conversation_count bigint,
  message_count bigint,
  conversations jsonb
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select i.* from private.admin_get_support_inbox() as i;
$function$;

revoke execute on function public.admin_get_support_inbox()
from public, anon, authenticated, service_role;
grant execute on function public.admin_get_support_inbox() to authenticated;

comment on function public.admin_get_support_inbox() is
'No-argument admin inbox endpoint. Guarded private helper checks the existing admin allowlist. Returns account contact details and compact conversation summaries; callers use nested conversation_id with admin_get_support_messages and support_request_id with admin_update_support_request. Read-only, with no schema/data changes.';

notify pgrst, 'reload schema';

