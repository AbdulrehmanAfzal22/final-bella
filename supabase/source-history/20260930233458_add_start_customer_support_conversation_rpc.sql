
create function public.start_customer_support_conversation(p_message text)
returns uuid
language plpgsql volatile security invoker
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_message text := btrim(p_message);
  v_sender record;
  v_existing_subjects text[];
  v_number bigint;
  v_subject text;
  v_request_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required.' using errcode = '42501';
  end if;
  if v_message is null or char_length(v_message) not between 1 and 10000 then
    raise exception 'Message must contain between 1 and 10000 characters.' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('maison-elan:customer-support-send:' || v_user_id::text, 0)
  );

  select s.* into v_sender from private.get_customer_support_sender() as s;
  select count(*) + 1,
    coalesce(array_agg(lower(btrim(c.subject))), array[]::text[])
  into v_number, v_existing_subjects
  from public.get_my_support_conversations() as c;

  loop
    v_subject := 'Customer Support #' || v_number::text;
    exit when not (lower(v_subject) = any(v_existing_subjects));
    v_number := v_number + 1;
  end loop;

  v_request_id := public.submit_support_request(
    p_customer_email => v_sender.customer_email,
    p_customer_name => v_sender.customer_name,
    p_customer_phone => v_sender.customer_phone,
    p_message => v_message,
    p_subject => v_subject
  );

  if not exists (
    select 1 from public.get_my_support_conversations() as c
    where c.id = v_request_id
  ) then
    raise exception 'Support conversation could not be retrieved.' using errcode = 'P0002';
  end if;
  return v_request_id;
end
$function$;
revoke all on function public.start_customer_support_conversation(text)
  from public, anon, authenticated, service_role;
grant execute on function public.start_customer_support_conversation(text) to authenticated;
comment on function public.start_customer_support_conversation(text) is
  'Starts a distinct signed-in customer support thread with its initial message. Uses the existing request, ownership, contact lookup, and conversation readers; returns the new conversation UUID.';
notify pgrst, 'reload schema';

