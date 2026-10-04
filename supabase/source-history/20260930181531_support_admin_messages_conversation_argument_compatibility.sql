
-- Preserve the existing implementation, identity, grants and dependencies.
alter function public.admin_get_support_messages(uuid) set schema private;

create function public.admin_get_support_messages(
  p_support_request_id uuid default null,
  p_conversation_id uuid default null
)
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
  v_request_id uuid := coalesce(p_conversation_id, p_support_request_id);
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Admin access required.' using errcode = '42501';
  end if;

  if p_support_request_id is not null
     and p_conversation_id is not null
     and p_support_request_id is distinct from p_conversation_id then
    raise exception 'Conversation and support request IDs must match when both are supplied.'
      using errcode = '22023';
  end if;

  if v_request_id is null then
    raise exception 'Support conversation or request ID is required.' using errcode = '22023';
  end if;

  return query
  select m.*
  from private.admin_get_support_messages(p_support_request_id => v_request_id) as m;
end;
$function$;

revoke execute on function public.admin_get_support_messages(uuid, uuid)
from public, anon, authenticated, service_role;
grant execute on function public.admin_get_support_messages(uuid, uuid) to authenticated;

comment on function public.admin_get_support_messages(uuid, uuid) is
'Admin-only compatibility endpoint: accepts p_conversation_id or legacy p_support_request_id. A positional single UUID also keeps its previous meaning. Both supplied IDs must match. One public signature avoids default-argument overload ambiguity. Delegates to the unchanged private message retrieval implementation.';

notify pgrst, 'reload schema';

