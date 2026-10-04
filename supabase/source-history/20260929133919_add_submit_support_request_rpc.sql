
create function public.submit_support_request(
  p_customer_email text,
  p_customer_name text,
  p_customer_phone text,
  p_message text,
  p_subject text
)
returns uuid
language plpgsql
volatile
security invoker
set search_path = ''
as $function$
declare
  v_request_id uuid := gen_random_uuid();
begin
  insert into public.support_requests (
    id,
    customer_name,
    customer_email,
    customer_phone,
    subject,
    message
  )
  values (
    v_request_id,
    p_customer_name,
    p_customer_email,
    p_customer_phone,
    p_subject,
    p_message
  );

  return v_request_id;
end
$function$;

revoke all on function public.submit_support_request(text, text, text, text, text)
  from public, anon, authenticated, service_role;
grant execute on function public.submit_support_request(text, text, text, text, text)
  to anon, authenticated;

comment on function public.submit_support_request(text, text, text, text, text) is
  'Submit a support request using caller INSERT privileges and RLS. Existing constraints validate fields and the support trigger normalizes data, assigns auth.uid() for signed-in callers, and timestamps the request. Returns only the newly generated request UUID; does not require or grant customer SELECT access.';

notify pgrst, 'reload schema';

