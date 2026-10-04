-- Cart mutation RPCs (cart_items only has a SELECT RLS policy today, so all
-- direct client writes to it were being rejected). These mirror the
-- SECURITY DEFINER pattern already used by save_product / is_admin.

create or replace function public.add_to_cart(p_variant_id uuid, p_quantity int)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_quantity < 1 or p_quantity > 99 then
    raise exception 'Invalid quantity';
  end if;
  if not exists (
    select 1 from public.product_variants pv
    join public.products p on p.id = pv.product_id
    where pv.id = p_variant_id and pv.active and p.status = 'published'
  ) then
    raise exception 'Product variant not available';
  end if;

  insert into public.carts(user_id) values (uid) on conflict (user_id) do nothing;
  insert into public.cart_items(user_id, variant_id, quantity)
  values (uid, p_variant_id, p_quantity)
  on conflict (user_id, variant_id)
  do update set quantity = least(public.cart_items.quantity + excluded.quantity, 99);
end;
$$;
grant execute on function public.add_to_cart(uuid, int) to authenticated;

create or replace function public.set_cart_quantity(p_variant_id uuid, p_quantity int)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_quantity < 1 or p_quantity > 99 then
    raise exception 'Invalid quantity';
  end if;
  update public.cart_items set quantity = p_quantity
  where user_id = uid and variant_id = p_variant_id;
  if not found then
    raise exception 'Cart item not found';
  end if;
end;
$$;
grant execute on function public.set_cart_quantity(uuid, int) to authenticated;

create or replace function public.remove_from_cart(p_variant_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  delete from public.cart_items where user_id = uid and variant_id = p_variant_id;
end;
$$;
grant execute on function public.remove_from_cart(uuid) to authenticated;

-- Atomic, server-priced checkout.
create or replace function public.process_checkout(shipping jsonb, shipping_cents int default 0)
returns table(order_id uuid, order_number bigint, total_cents bigint)
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  v_order_id uuid;
  v_order_number bigint;
  v_subtotal bigint := 0;
  item record;
begin
  if uid is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if not exists (select 1 from public.cart_items where user_id = uid) then
    raise exception 'Cart is empty';
  end if;

  perform 1 from public.product_variants pv
    join public.cart_items ci on ci.variant_id = pv.id
    where ci.user_id = uid
    for update;

  for item in
    select ci.variant_id, ci.quantity, pv.stock, pv.active
    from public.cart_items ci
    join public.product_variants pv on pv.id = ci.variant_id
    where ci.user_id = uid
  loop
    if not item.active or item.stock < item.quantity then
      raise exception 'Insufficient stock for one or more items' using errcode = '23514';
    end if;
  end loop;

  insert into public.orders (user_id, status, payment_status, subtotal_cents, shipping_cents, total_cents, shipping_address)
  values (uid, 'pending', 'unpaid', 0, coalesce(shipping_cents, 0), 0, shipping)
  returning id, order_number into v_order_id, v_order_number;

  insert into public.order_items (order_id, variant_id, product_name, color, size, image_path, unit_price_cents, quantity)
  select v_order_id, pv.id, p.name, pv.color, pv.size,
    (select path from public.product_images where product_id = p.id order by position limit 1),
    p.price_cents, ci.quantity
  from public.cart_items ci
  join public.product_variants pv on pv.id = ci.variant_id
  join public.products p on p.id = pv.product_id
  where ci.user_id = uid;

  select coalesce(sum(unit_price_cents * quantity), 0) into v_subtotal
  from public.order_items where order_id = v_order_id;

  update public.orders
  set subtotal_cents = v_subtotal, total_cents = v_subtotal + coalesce(shipping_cents, 0)
  where id = v_order_id;

  update public.product_variants pv
  set stock = pv.stock - ci.quantity
  from public.cart_items ci
  where pv.id = ci.variant_id and ci.user_id = uid;

  insert into public.order_status_history(order_id, status) values (v_order_id, 'pending');

  delete from public.cart_items where user_id = uid;

  return query select v_order_id, v_order_number, v_subtotal + coalesce(shipping_cents, 0);
end;
$$;
grant execute on function public.process_checkout(jsonb, int) to authenticated;

-- Admin order status updates, recorded to history atomically.
create or replace function public.set_order_status(p_order_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  if p_status not in ('pending','confirmed','processing','shipped','delivered','cancelled') then
    raise exception 'Invalid status';
  end if;
  update public.orders set status = p_status where id = p_order_id;
  if not found then
    raise exception 'Order not found';
  end if;
  insert into public.order_status_history(order_id, status) values (p_order_id, p_status);
end;
$$;
grant execute on function public.set_order_status(uuid, text) to authenticated;

-- Reviews (table did not exist; src/services/reviews.js referenced it).
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rating int not null check (rating between 1 and 5),
  comment text not null default '' check (length(comment) <= 2000),
  approved boolean not null default false,
  created_at timestamptz not null default now(),
  unique(product_id, user_id)
);
alter table public.reviews enable row level security;

create policy reviews_read on public.reviews for select
  to anon, authenticated
  using (approved = true or user_id = auth.uid() or private.is_admin());

create policy reviews_insert_own on public.reviews for insert
  to authenticated
  with check (user_id = auth.uid());

create policy reviews_admin_update on public.reviews for update
  to authenticated
  using (private.is_admin());

create policy reviews_admin_delete on public.reviews for delete
  to authenticated
  using (private.is_admin());
