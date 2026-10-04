-- Existing cloth-web schema only. No table, FK, RLS, or archive changes.
set local lock_timeout = '5s';
set local statement_timeout = '30s';

create function private.admin_delete_product_impl(p_product_id uuid, p_cleanup_only boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
set lock_timeout = '5s'
as $$
declare
  v_product_exists boolean;
  v_paths text[];
  v_deleted integer;
  v_history_message constant text := 'This product cannot be permanently deleted because it is associated with historical orders. Please archive it instead.';
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if not private.is_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  if p_product_id is null or p_cleanup_only is null then
    raise exception 'A single product ID and a valid operation are required.' using errcode = '22023';
  end if;

  -- Same parent-before-variant lock order used by checkout. No order code changes.
  perform 1 from public.products p where p.id = p_product_id for update;
  v_product_exists := found;
  if p_cleanup_only and v_product_exists then
    raise exception 'The product still exists. Image cleanup was not performed.' using errcode = '23503';
  end if;
  if not p_cleanup_only and not v_product_exists then
    raise exception 'Product not found.' using errcode = 'P0002';
  end if;

  perform v.id from public.product_variants v
  where v.product_id = p_product_id order by v.id for update;

  if exists (
    select 1 from public.order_items oi
    join public.product_variants v on v.id = oi.variant_id
    where v.product_id = p_product_id
  ) or exists (
    select 1 from public.order_items oi
    where starts_with(oi.image_path, p_product_id::text || '/')
       or oi.image_path in (select i.path from public.product_images i where i.product_id = p_product_id)
  ) then
    raise exception '%', v_history_message using errcode = '23503';
  end if;

  -- Storage files use <product UUID>/<filename>. Include older unlinked uploads,
  -- but never accept a client-supplied path or a different product's folder.
  if exists (
    select 1 from public.product_images i
    where i.product_id = p_product_id and (
      not starts_with(i.path, p_product_id::text || '/')
      or i.path like '%/../%' or i.path like '%/./%' or position(chr(92) in i.path) > 0
    )
  ) then
    raise exception 'Product media ownership could not be verified. Please archive it instead.' using errcode = '23503';
  end if;

  select coalesce(array_agg(paths.path order by paths.path), '{}'::text[]) into v_paths
  from (
    select o.name as path from storage.objects o
    where o.bucket_id = 'product-images' and starts_with(o.name, p_product_id::text || '/')
    union
    select i.path from public.product_images i where i.product_id = p_product_id
  ) paths;

  if exists (
    select 1 from public.product_images i
    where i.product_id <> p_product_id and i.path = any(v_paths)
  ) or exists (
    select 1 from public.categories c, unnest(v_paths) path
    where c.image_path = path or c.image_url = path
       or position('/product-images/' || path in coalesce(c.image_url, '')) > 0
  ) or exists (
    select 1 from public.instagram_reels r, unnest(v_paths) path
    where position('/product-images/' || path in coalesce(r.media_url, '')) > 0
       or position('/product-images/' || path in coalesce(r.thumbnail_url, '')) > 0
       or position('/product-images/' || path in coalesce(r.profile_image, '')) > 0
  ) then
    raise exception 'Product images are used by another record. Please archive this product instead.' using errcode = '23503';
  end if;

  if not p_cleanup_only then
    -- Only links to this product's variants are removed; carts themselves stay.
    delete from public.cart_items ci using public.product_variants v
    where ci.variant_id = v.id and v.product_id = p_product_id;

    -- Existing FKs remove product-owned images, variants, reviews and wishlist
    -- links. Categories remain; existing Reel links become NULL, not deleted.
    delete from public.products p where p.id = p_product_id;
    get diagnostics v_deleted = row_count;
    if v_deleted <> 1 then
      raise exception 'Product could not be deleted.' using errcode = 'P0001';
    end if;
  end if;

  return jsonb_build_object(
    'product_id', p_product_id,
    'product_deleted', true,
    'cleanup_only', p_cleanup_only,
    'storage_bucket', 'product-images',
    'storage_paths', to_jsonb(v_paths)
  );
end;
$$;

revoke all on function private.admin_delete_product_impl(uuid, boolean) from public, anon, authenticated;
grant execute on function private.admin_delete_product_impl(uuid, boolean) to authenticated;

create function public.admin_delete_product(p_product_id uuid, p_cleanup_only boolean default false)
returns jsonb
language sql
security invoker
set search_path = ''
as $$ select private.admin_delete_product_impl($1, $2); $$;

revoke all on function public.admin_delete_product(uuid, boolean) from public, anon, authenticated;
grant execute on function public.admin_delete_product(uuid, boolean) to authenticated;

notify pgrst, 'reload schema';

