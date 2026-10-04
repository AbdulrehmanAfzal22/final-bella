create or replace function public.delete_product(p_product_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  product_name text;
  image_paths text[];
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  select p.name into product_name
  from public.products p
  where p.id = p_product_id
  for update;

  if not found then
    raise exception 'Product not found';
  end if;

  select coalesce(array_agg(pi.path), array[]::text[])
  into image_paths
  from public.product_images pi
  where pi.product_id = p_product_id;

  if exists (
    select 1
    from unnest(image_paths) as image_rows(path)
    where image_rows.path not like p_product_id::text || '/%'
  ) then
    raise exception 'Product image path is outside the product storage folder';
  end if;

  if exists (
    select 1
    from public.order_items oi
    join public.product_variants pv on pv.id = oi.variant_id
    where pv.product_id = p_product_id
  ) then
    raise exception 'This product appears in order history and cannot be permanently deleted. Archive it instead.'
      using errcode = '23503';
  end if;

  delete from public.cart_items ci
  using public.product_variants pv
  where ci.variant_id = pv.id
    and pv.product_id = p_product_id;

  delete from public.wishlist_items wi where wi.product_id = p_product_id;
  delete from public.reviews r where r.product_id = p_product_id;
  delete from public.product_images pi where pi.product_id = p_product_id;
  delete from public.product_variants pv where pv.product_id = p_product_id;
  delete from public.products p where p.id = p_product_id;

  return jsonb_build_object(
    'product_id', p_product_id,
    'product_name', product_name,
    'image_paths', to_jsonb(image_paths)
  );
end;
$$;

revoke all on function public.delete_product(uuid) from public, anon;
grant execute on function public.delete_product(uuid) to authenticated;