
alter table public.support_requests
  add column admin_reply text not null default '',
  add constraint support_requests_reply_check
    check (char_length(admin_reply) <= 10000);

comment on column public.support_requests.admin_reply is
  'Admin-authored reply text. Stored separately from the internal admin_note; saving does not send a notification.';

alter policy support_requests_public_insert
  on public.support_requests
  to anon, authenticated
  with check (
    status = 'new'
    and admin_note = ''
    and admin_reply = ''
  );

grant update (admin_reply) on public.support_requests to authenticated;

create function public.admin_update_support_request(
  p_id uuid,
  p_status text default null,
  p_admin_note text default null,
  p_admin_reply text default null
)
returns setof public.support_requests
language plpgsql
volatile
security invoker
set search_path = ''
as $function$
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Admin access required.' using errcode = '42501';
  end if;

  if p_id is null then
    raise exception 'Support request ID is required.' using errcode = '22023';
  end if;

  if p_status is not null
    and p_status not in ('new', 'in_progress', 'resolved', 'closed') then
    raise exception 'Invalid support request status.' using errcode = '22023';
  end if;

  if char_length(p_admin_note) > 10000 then
    raise exception 'Admin note must be 10000 characters or fewer.' using errcode = '22023';
  end if;

  if char_length(p_admin_reply) > 10000 then
    raise exception 'Admin reply must be 10000 characters or fewer.' using errcode = '22023';
  end if;

  return query
    update public.support_requests as r
    set
      status = coalesce(p_status, r.status),
      admin_note = coalesce(p_admin_note, r.admin_note),
      admin_reply = coalesce(p_admin_reply, r.admin_reply)
    where r.id = p_id
    returning r.*;

  if not found then
    raise exception 'Support request not found.' using errcode = 'P0002';
  end if;
end
$function$;

revoke all on function public.admin_update_support_request(uuid, text, text, text)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_update_support_request(uuid, text, text, text)
  to authenticated;

comment on function public.admin_update_support_request(uuid, text, text, text) is
  'Admin-only update of support status, internal note, and reply. Returns the updated row under caller RLS. Null or omitted text parameters preserve current values; empty note or reply clears that field.';

notify pgrst, 'reload schema';

