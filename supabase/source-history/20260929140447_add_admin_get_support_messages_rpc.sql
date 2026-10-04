
create function public.admin_get_support_messages(p_support_request_id uuid)
returns table (
  id uuid,
  support_request_id uuid,
  sender_type text,
  message text,
  created_at timestamptz,
  timestamp_source text
)
language plpgsql
stable
security invoker
set search_path = ''
as $function$
declare
  v_request public.support_requests%rowtype;
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Admin access required.' using errcode = '42501';
  end if;

  if p_support_request_id is null then
    raise exception 'Support request ID is required.' using errcode = '22023';
  end if;

  select r.* into v_request
  from public.support_requests as r
  where r.id = p_support_request_id;

  if not found then
    raise exception 'Support request not found.' using errcode = 'P0002';
  end if;

  return query
  with related_requests as (
    select r.*
    from public.support_requests as r
    where lower(btrim(r.subject)) = lower(btrim(v_request.subject))
      and r.user_id is not distinct from v_request.user_id
      and (
        v_request.user_id is not null
        or r.customer_email = v_request.customer_email
      )
  ),
  stored_messages as (
    select
      r.id as message_id,
      r.id as request_id,
      'customer'::text as sender,
      r.message as message_text,
      r.created_at as message_timestamp,
      'request_created_at'::text as time_source,
      0 as sender_order
    from related_requests as r

    union all

    select
      md5('maison-elan:support-request:admin-reply:' || r.id::text)::uuid,
      r.id,
      'admin'::text,
      r.admin_reply,
      r.updated_at,
      'request_updated_at_not_original_reply_timestamp'::text,
      1
    from related_requests as r
    where btrim(r.admin_reply) <> ''
  )
  select
    m.message_id,
    m.request_id,
    m.sender,
    m.message_text,
    m.message_timestamp,
    m.time_source
  from stored_messages as m
  order by m.message_timestamp asc, m.sender_order asc, m.message_id asc;
end
$function$;

revoke all on function public.admin_get_support_messages(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_get_support_messages(uuid) to authenticated;

comment on function public.admin_get_support_messages(uuid) is
  'Admin-only read projection of existing support request messages and current admin replies. Groups case-insensitive trimmed subjects within the same user_id, or the same email among guest/legacy rows. Does not join the older support_tickets/support_messages system or expose internal notes as messages. Admin reply IDs are deterministic projection IDs, not stored message IDs. Reply created_at uses the request last-update timestamp and is explicitly marked by timestamp_source; original reply timestamps and overwritten reply history were not stored.';

notify pgrst, 'reload schema';

