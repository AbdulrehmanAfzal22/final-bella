
create table public.support_request_replies (
  id uuid primary key default gen_random_uuid(),
  support_request_id uuid not null
    references public.support_requests(id) on delete cascade,
  sender_id uuid references auth.users(id) on delete set null,
  message text not null,
  created_at timestamptz not null default clock_timestamp(),
  is_legacy_snapshot boolean not null default false,
  legacy_updated_at timestamptz,
  constraint support_request_replies_message_check check (
    char_length(message) <= 10000 and char_length(btrim(message)) between 1 and 10000
  ),
  constraint support_request_replies_legacy_check check (
    (is_legacy_snapshot and sender_id is null and legacy_updated_at is not null)
    or (not is_legacy_snapshot and legacy_updated_at is null)
  )
);
comment on table public.support_request_replies is
  'Append-only replies for support_requests. Separate from the existing support_tickets/support_messages system.';
comment on column public.support_request_replies.legacy_updated_at is
  'Last request update timestamp for a captured legacy admin_reply; not its original send timestamp.';
create index support_request_replies_request_created_idx
  on public.support_request_replies(support_request_id, created_at desc, id desc);
create index support_request_replies_sender_idx
  on public.support_request_replies(sender_id);
alter table public.support_request_replies enable row level security;
revoke all on table public.support_request_replies from public, anon, authenticated;
grant select on table public.support_request_replies to authenticated;
grant insert (support_request_id, sender_id, message, is_legacy_snapshot, legacy_updated_at)
  on public.support_request_replies to authenticated;
create policy support_request_replies_admin_read
  on public.support_request_replies for select to authenticated
  using ((select private.is_admin()));
create policy support_request_replies_admin_insert
  on public.support_request_replies for insert to authenticated
  with check (
    (select private.is_admin())
    and (
      (not is_legacy_snapshot and sender_id = (select auth.uid()) and legacy_updated_at is null)
      or (is_legacy_snapshot and sender_id is null and legacy_updated_at is not null)
    )
  );

create function private.support_message_feed(p_request_ids uuid[])
returns table(
  id uuid, support_request_id uuid, sender_type text, message text,
  created_at timestamptz, timestamp_source text
)
language plpgsql stable security definer set search_path = ''
as $feed$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_is_admin boolean;
begin
  if v_user_id is null then
    raise exception 'Authentication required.' using errcode = '42501';
  end if;
  select case when u.email_confirmed_at is not null then lower(btrim(u.email)) end
    into v_email from auth.users as u where u.id = v_user_id;
  if not found then return; end if;
  v_is_admin := private.is_admin();

  return query
  with eligible_requests as materialized (
    select r.* from public.support_requests as r
    where r.id = any(p_request_ids)
      and (
        v_is_admin or r.user_id = v_user_id
        or (
          r.user_id is null and v_email is not null and v_email <> ''
          and r.customer_email = v_email
        )
      )
  ),
  archived_replies as materialized (
    select a.* from public.support_request_replies as a
    join eligible_requests as r on r.id = a.support_request_id
  ),
  latest_archived as (
    select distinct on (a.support_request_id) a.support_request_id, a.message
    from archived_replies as a
    order by a.support_request_id, a.created_at desc, a.id desc
  ),
  feed as (
    select r.id as message_id, r.id as request_id,
      'customer'::text as sender, r.message as message_text,
      r.created_at as message_timestamp, 'request_created_at'::text as time_source,
      0 as sender_order
    from eligible_requests as r
    union all
    select a.id, a.support_request_id, 'admin'::text, a.message,
      case when a.is_legacy_snapshot then a.legacy_updated_at else a.created_at end,
      case when a.is_legacy_snapshot
        then 'request_updated_at_not_original_reply_timestamp'::text
        else 'stored_support_reply_created_at'::text end,
      1
    from archived_replies as a
    union all
    select md5('maison-elan:support-request:admin-reply:' || r.id::text)::uuid,
      r.id, 'admin'::text, r.admin_reply, r.updated_at,
      'request_updated_at_not_original_reply_timestamp'::text, 1
    from eligible_requests as r
    left join latest_archived as a on a.support_request_id = r.id
    where btrim(r.admin_reply) <> '' and a.message is distinct from r.admin_reply
  )
  select f.message_id, f.request_id, f.sender, f.message_text,
    f.message_timestamp, f.time_source
  from feed as f
  order by f.message_timestamp asc, f.sender_order asc, f.message_id asc;
end
$feed$;
revoke all on function private.support_message_feed(uuid[])
  from public, anon, authenticated, service_role;
grant execute on function private.support_message_feed(uuid[]) to authenticated;
comment on function private.support_message_feed(uuid[]) is
  'Support messages with stored reply history, filtered to admins or verified request owners.';

create function public.admin_send_support_message(p_conversation_id uuid, p_message text)
returns uuid
language plpgsql volatile security invoker set search_path = ''
as $send$
declare
  v_anchor public.support_requests%rowtype;
  v_target public.support_requests%rowtype;
  v_message text := btrim(p_message);
  v_latest_archived text;
  v_message_id uuid;
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Admin access required.' using errcode = '42501';
  end if;
  if p_conversation_id is null then
    raise exception 'Conversation ID is required.' using errcode = '22023';
  end if;
  if v_message is null or char_length(v_message) not between 1 and 10000 then
    raise exception 'Message must contain 1 to 10000 characters.' using errcode = '22023';
  end if;
  select r.* into v_anchor from public.support_requests as r
    where r.id = p_conversation_id;
  if not found then
    raise exception 'Support conversation not found.' using errcode = 'P0002';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'maison-elan:admin-support-send:'
    || coalesce(v_anchor.user_id::text, 'guest:' || v_anchor.customer_email)
    || ':' || lower(btrim(v_anchor.subject)), 0
  ));
  select r.* into v_target
  from public.support_requests as r
  where lower(btrim(r.subject)) = lower(btrim(v_anchor.subject))
    and r.user_id is not distinct from v_anchor.user_id
    and (v_anchor.user_id is not null or r.customer_email = v_anchor.customer_email)
  order by r.created_at desc, r.id desc
  limit 1 for update;
  if not found then
    raise exception 'Support conversation not found.' using errcode = 'P0002';
  end if;

  select a.message into v_latest_archived
  from public.support_request_replies as a
  where a.support_request_id = v_target.id
  order by a.created_at desc, a.id desc limit 1;
  if btrim(v_target.admin_reply) <> '' and v_latest_archived is distinct from v_target.admin_reply then
    insert into public.support_request_replies(
      support_request_id, sender_id, message, is_legacy_snapshot, legacy_updated_at
    ) values (v_target.id, null, v_target.admin_reply, true, v_target.updated_at);
  end if;

  insert into public.support_request_replies(support_request_id, sender_id, message)
    values (v_target.id, auth.uid(), v_message)
    returning id into v_message_id;
  perform 1 from public.admin_update_support_request(
    p_id => v_target.id, p_admin_reply => v_message
  );
  return v_message_id;
end
$send$;
revoke all on function public.admin_send_support_message(uuid,text)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_send_support_message(uuid,text) to authenticated;
comment on function public.admin_send_support_message(uuid,text) is
  'Admin-only append of a support reply. Returns stored message UUID, preserves history and keeps the legacy latest-reply cache.';

create or replace function private.admin_get_support_messages(p_support_request_id uuid)
returns table(
  id uuid, support_request_id uuid, sender_type text, message text,
  created_at timestamptz, timestamp_source text
)
language plpgsql stable security invoker set search_path = ''
as $admin_messages$
declare
  v_request public.support_requests%rowtype;
  v_request_ids uuid[];
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Admin access required.' using errcode = '42501';
  end if;
  if p_support_request_id is null then
    raise exception 'Support request ID is required.' using errcode = '22023';
  end if;
  select r.* into v_request from public.support_requests as r
    where r.id = p_support_request_id;
  if not found then
    raise exception 'Support request not found.' using errcode = 'P0002';
  end if;
  select array_agg(r.id) into v_request_ids
  from public.support_requests as r
  where lower(btrim(r.subject)) = lower(btrim(v_request.subject))
    and r.user_id is not distinct from v_request.user_id
    and (v_request.user_id is not null or r.customer_email = v_request.customer_email);
  return query
    select m.id, m.support_request_id, m.sender_type, m.message, m.created_at, m.timestamp_source
    from private.support_message_feed(v_request_ids) as m;
end
$admin_messages$;

CREATE OR REPLACE FUNCTION private.get_my_support_conversations()
 RETURNS TABLE(id uuid, subject text, status text, message text, admin_reply text, created_at timestamp with time zone, updated_at timestamp with time zone, message_count bigint, messages jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    select r.subject_key,
      m.id as message_id,
      m.support_request_id as request_id,
      m.sender_type as sender,
      m.message as message_text,
      m.created_at as message_timestamp,
      m.timestamp_source as time_source,
      case when m.sender_type = 'customer' then 0 else 1 end as sender_order
    from private.support_message_feed(
      array(select r0.id from owned_requests as r0)
    ) as m
    join owned_requests as r on r.id = m.support_request_id
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
$function$
;

CREATE OR REPLACE FUNCTION private.admin_get_support_inbox()
 RETURNS TABLE(id uuid, user_id uuid, customer_name text, customer_email text, customer_phone text, subject text, status text, message text, admin_reply text, admin_note text, created_at timestamp with time zone, updated_at timestamp with time zone, conversation_id uuid, support_request_id uuid, conversation_count bigint, message_count bigint, conversations jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  request_message_counts as (
    select m.support_request_id, count(*) as stored_message_count
    from private.support_message_feed(
      array(select r0.id from request_context as r0)
    ) as m
    group by m.support_request_id
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
      sum(coalesce(mc.stored_message_count, 0))::bigint as stored_message_count
    from request_context as r
    left join request_message_counts as mc on mc.support_request_id = r.id
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
$function$
;

notify pgrst, 'reload schema';

