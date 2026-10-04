
create function public.get_my_support_messages(p_conversation_id uuid)
returns table (
  id uuid,
  conversation_id uuid,
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
  v_messages jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.' using errcode = '42501';
  end if;

  if p_conversation_id is null then
    raise exception 'Support conversation ID is required.' using errcode = '22023';
  end if;

  select c.messages into v_messages
  from public.get_my_support_conversations() as c
  where c.id = p_conversation_id;

  if not found then
    raise exception 'Support conversation not found or unavailable.' using errcode = 'P0002';
  end if;

  return query
  select
    m.id,
    p_conversation_id,
    m.support_request_id,
    m.sender_type,
    m.message,
    m.created_at,
    m.timestamp_source
  from pg_catalog.jsonb_array_elements(v_messages) with ordinality as e(value, position)
  cross join lateral pg_catalog.jsonb_to_record(e.value) as m(
    id uuid,
    support_request_id uuid,
    sender_type text,
    message text,
    created_at timestamptz,
    timestamp_source text
  )
  order by e.position;
end;
$function$;

revoke execute on function public.get_my_support_messages(uuid)
from public, anon, authenticated, service_role;
grant execute on function public.get_my_support_messages(uuid) to authenticated;

comment on function public.get_my_support_messages(uuid) is
'Read-only messages for a canonical conversation ID returned by get_my_support_conversations(). Reuses its caller ownership checks and ordering. Includes stored customer messages and current saved admin replies only; no internal notes. Admin reply timestamps are request updated_at, not original send timestamps.';

notify pgrst, 'reload schema';

