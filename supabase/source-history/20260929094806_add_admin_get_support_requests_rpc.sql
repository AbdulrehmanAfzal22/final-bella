
create function public.admin_get_support_requests()
returns setof public.support_requests
language plpgsql
stable
security invoker
set search_path = ''
as $function$
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Admin access required.' using errcode = '42501';
  end if;

  return query
    select r.*
    from public.support_requests r
    order by r.created_at desc, r.id desc;
end
$function$;

revoke all on function public.admin_get_support_requests()
  from public, anon, authenticated, service_role;
grant execute on function public.admin_get_support_requests()
  to authenticated;

comment on function public.admin_get_support_requests() is
  'Admin-only support request listing. Takes no arguments, returns support_requests rows newest first, and preserves caller RLS.';

notify pgrst, 'reload schema';

