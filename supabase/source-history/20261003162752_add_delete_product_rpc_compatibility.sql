
set local lock_timeout = '5s';
set local statement_timeout = '30s';

create function public.delete_product(p_product_id uuid)
returns jsonb
language sql
security invoker
set search_path = ''
as $function$
  select public.admin_delete_product(p_product_id, false);
$function$;

comment on function public.delete_product(uuid) is
'Compatibility RPC for existing admin frontend. Uses the existing authenticated admin-only transactional product deletion and historical-order protections. Returns the validated Storage cleanup manifest; complete file removal uses the delete-product Edge Function and Storage API.';

revoke all on function public.delete_product(uuid) from public, anon, authenticated, service_role;
grant execute on function public.delete_product(uuid) to authenticated;

notify pgrst, 'reload schema';

