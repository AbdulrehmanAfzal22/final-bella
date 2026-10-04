-- Original workflow schema from cloth-web, exported read-only.
-- Target: an EMPTY, separate bellabyrt project. No users, orders or files are copied.
-- Replayed successfully into bellabyrt (bpedttjsbmuvtyqehvnx) on 4 October 2026.

-- 20260923144917 commerce_foundation

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, anon;
create table private.admin_members(user_id uuid primary key references auth.users(id) on delete cascade, created_at timestamptz not null default now());
alter table private.admin_members enable row level security;
revoke all on private.admin_members from public,anon,authenticated;
create function private.is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from private.admin_members where user_id=auth.uid())
$$;
revoke all on function private.is_admin() from public;
grant execute on function private.is_admin() to anon,authenticated;
create function public.is_admin() returns boolean language sql stable security invoker set search_path='' as $$select private.is_admin()$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

create table public.profiles(id uuid primary key references auth.users(id) on delete cascade,full_name text not null default '' check(length(full_name)<=150), created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.categories(id uuid primary key default gen_random_uuid(), name text not null unique check(length(trim(name)) between 1 and 80),slug text not null unique check(slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),created_at timestamptz not null default now());
create table public.products(id uuid primary key default gen_random_uuid(),category_id uuid references public.categories(id) on delete restrict,name text not null check(length(trim(name)) between 1 and 200),description text not null default '' check(length(description)<=8000),care text not null default '',price_cents integer not null check(price_cents>0 and price_cents<=100000000),status text not null default 'draft' check(status in('draft','published','archived')),featured boolean not null default false,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.product_images(id uuid primary key default gen_random_uuid(),product_id uuid not null references public.products(id) on delete cascade,path text not null unique,color text,alt text not null default '',position integer not null default 0 check(position>=0),created_at timestamptz not null default now());
create table public.product_variants(id uuid primary key default gen_random_uuid(),product_id uuid not null references public.products(id) on delete cascade,color text not null check(length(trim(color)) between 1 and 50),color_hex text not null default '#24211e' check(color_hex ~ '^#[0-9a-fA-F]{6}$'),size text not null check(length(trim(size)) between 1 and 30),stock integer not null default 0 check(stock>=0 and stock<=1000000),active boolean not null default true,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(product_id,color,size));
create table public.addresses(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,label text not null default 'Home',full_name text not null check(length(trim(full_name)) between 1 and 150),line1 text not null check(length(trim(line1)) between 1 and 300),city text not null check(length(trim(city)) between 1 and 150),postal_code text not null default '',country text not null check(length(trim(country)) between 1 and 100),phone text not null default '',created_at timestamptz not null default now());
create table public.wishlists(user_id uuid primary key references auth.users(id) on delete cascade,created_at timestamptz not null default now());
create table public.wishlist_items(user_id uuid not null references public.wishlists(user_id) on delete cascade,product_id uuid not null references public.products(id) on delete cascade,created_at timestamptz not null default now(),primary key(user_id,product_id));
create table public.carts(user_id uuid primary key references auth.users(id) on delete cascade,updated_at timestamptz not null default now());
create table public.cart_items(user_id uuid not null references public.carts(user_id) on delete cascade,variant_id uuid not null references public.product_variants(id) on delete restrict,quantity integer not null check(quantity between 1 and 99),created_at timestamptz not null default now(),primary key(user_id,variant_id));
create table public.orders(id uuid primary key default gen_random_uuid(),order_number bigint generated always as identity unique,user_id uuid not null references auth.users(id) on delete restrict,request_id uuid not null,status text not null default 'pending' check(status in('pending','confirmed','processing','shipped','delivered','cancelled')),payment_status text not null default 'unpaid' check(payment_status in('unpaid','paid','refunded')),subtotal_cents bigint not null check(subtotal_cents>=0),shipping_cents integer not null default 0 check(shipping_cents>=0),total_cents bigint not null check(total_cents=subtotal_cents+shipping_cents),currency text not null default 'USD' check(currency='USD'),shipping_address jsonb not null,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(user_id,request_id));
create table public.order_items(id uuid primary key default gen_random_uuid(),order_id uuid not null references public.orders(id) on delete cascade,variant_id uuid references public.product_variants(id) on delete restrict,product_name text not null,color text not null,size text not null,image_path text,unit_price_cents integer not null check(unit_price_cents>0),quantity integer not null check(quantity between 1 and 99));
create table public.order_status_history(id uuid primary key default gen_random_uuid(),order_id uuid not null references public.orders(id) on delete cascade,status text not null check(status in('pending','confirmed','processing','shipped','delivered','cancelled')),created_at timestamptz not null default now());
create table public.admin_notes(id uuid primary key default gen_random_uuid(),order_id uuid not null references public.orders(id) on delete cascade,note text not null check(length(trim(note)) between 1 and 4000),created_at timestamptz not null default now());

create index products_status_created_idx on public.products(status,created_at desc);
create index products_category_idx on public.products(category_id);
create index product_images_product_idx on public.product_images(product_id,position);
create index variants_product_idx on public.product_variants(product_id);
create index addresses_user_idx on public.addresses(user_id);
create index wishlist_product_idx on public.wishlist_items(product_id);
create index cart_variant_idx on public.cart_items(variant_id);
create index orders_user_created_idx on public.orders(user_id,created_at desc);
create index orders_status_idx on public.orders(status);
create index order_items_order_idx on public.order_items(order_id);
create index order_items_variant_idx on public.order_items(variant_id);
create index order_history_order_idx on public.order_status_history(order_id,created_at);
create index admin_notes_order_idx on public.admin_notes(order_id);

create function private.touch_updated_at() returns trigger language plpgsql set search_path='' as $$begin new.updated_at=now(); return new; end$$;
revoke all on function private.touch_updated_at() from public;
create trigger products_updated before update on public.products for each row execute function private.touch_updated_at();
create trigger variants_updated before update on public.product_variants for each row execute function private.touch_updated_at();
create trigger profiles_updated before update on public.profiles for each row execute function private.touch_updated_at();
create trigger orders_updated before update on public.orders for each row execute function private.touch_updated_at();
create function private.new_customer() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.profiles(id,full_name) values(new.id,left(coalesce(new.raw_user_meta_data->>'full_name',''),150));
 insert into public.carts(user_id) values(new.id);
 insert into public.wishlists(user_id) values(new.id);
 return new;
end$$;
revoke all on function private.new_customer() from public;
create trigger on_customer_signup after insert on auth.users for each row execute function private.new_customer();

do $$declare t text;begin
 foreach t in array array['profiles','categories','products','product_images','product_variants','addresses','wishlists','wishlist_items','carts','cart_items','orders','order_items','order_status_history','admin_notes'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from anon,authenticated',t);
 end loop;
end$$;
grant select on public.categories,public.products,public.product_images,public.product_variants to anon,authenticated;
grant insert,update,delete on public.categories,public.products,public.product_images,public.product_variants to authenticated;
create policy categories_read on public.categories for select to anon,authenticated using(true);
create policy categories_admin on public.categories for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy products_read on public.products for select to anon,authenticated using(status='published' or (select private.is_admin()));
create policy products_admin on public.products for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy images_read on public.product_images for select to anon,authenticated using(exists(select 1 from public.products p where p.id=product_id and p.status='published') or (select private.is_admin()));
create policy images_admin on public.product_images for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));
create policy variants_read on public.product_variants for select to anon,authenticated using((active and exists(select 1 from public.products p where p.id=product_id and p.status='published')) or (select private.is_admin()));
create policy variants_admin on public.product_variants for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));

grant select on public.profiles,public.addresses,public.wishlists,public.wishlist_items,public.carts,public.cart_items,public.orders,public.order_items,public.order_status_history,public.admin_notes to authenticated;
grant update(full_name) on public.profiles to authenticated;
create policy profile_read on public.profiles for select to authenticated using(id=(select auth.uid()) or (select private.is_admin()));
create policy profile_update on public.profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
grant insert,update,delete on public.addresses,public.wishlist_items to authenticated;
create policy addresses_owner on public.addresses for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy wishlist_owner on public.wishlists for select to authenticated using(user_id=(select auth.uid()));
create policy wishlist_items_owner on public.wishlist_items for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy cart_owner on public.carts for select to authenticated using(user_id=(select auth.uid()));
create policy cart_items_owner on public.cart_items for select to authenticated using(user_id=(select auth.uid()));
create policy orders_read on public.orders for select to authenticated using(user_id=(select auth.uid()) or (select private.is_admin()));
create policy order_items_read on public.order_items for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id));
create policy history_read on public.order_status_history for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id));
grant insert on public.admin_notes to authenticated;
create policy notes_admin on public.admin_notes for all to authenticated using((select private.is_admin())) with check((select private.is_admin()));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('product-images','product-images',true,5242880,array['image/jpeg','image/png','image/webp']);
create policy product_images_admin_insert on storage.objects for insert to authenticated with check(bucket_id='product-images' and (select private.is_admin()));
create policy product_images_admin_read on storage.objects for select to authenticated using(bucket_id='product-images' and (select private.is_admin()));
create policy product_images_admin_delete on storage.objects for delete to authenticated using(bucket_id='product-images' and (select private.is_admin()));
create policy product_images_admin_update on storage.objects for update to authenticated using(bucket_id='product-images' and (select private.is_admin())) with check(bucket_id='product-images' and (select private.is_admin()));

create function public.save_product(payload jsonb) returns uuid language plpgsql security invoker set search_path='' as $$
declare pid uuid=(payload->>'id')::uuid; item jsonb; vid uuid; ids uuid[]='{}';
begin
 if not private.is_admin() then raise exception 'Admin access required' using errcode='42501';end if;
 if jsonb_array_length(payload->'variants')<1 then raise exception 'Add at least one variant';end if;
 if payload->>'status'='published' and jsonb_array_length(payload->'images')<1 then raise exception 'Upload at least one image before publishing';end if;
 insert into public.products(id,name,description,care,price_cents,category_id,status,featured)
 values(pid,trim(payload->>'name'),coalesce(payload->>'description',''),coalesce(payload->>'care',''),(payload->>'price_cents')::int,nullif(payload->>'category_id','')::uuid,payload->>'status',coalesce((payload->>'featured')::boolean,false))
 on conflict(id) do update set name=excluded.name,description=excluded.description,care=excluded.care,price_cents=excluded.price_cents,category_id=excluded.category_id,status=excluded.status,featured=excluded.featured;
 for item in select * from jsonb_array_elements(payload->'variants') loop
  vid=coalesce(nullif(item->>'id','')::uuid,gen_random_uuid());
  if exists(select 1 from public.product_variants where id=vid and product_id<>pid) then raise exception 'Variant belongs to another product';end if;
  insert into public.product_variants(id,product_id,color,color_hex,size,stock,active)
  values(vid,pid,trim(item->>'color'),item->>'color_hex',trim(item->>'size'),(item->>'stock')::int,true)
  on conflict(id) do update set color=excluded.color,color_hex=excluded.color_hex,size=excluded.size,stock=excluded.stock,active=true;
  ids=array_append(ids,vid);
 end loop;
 update public.product_variants set active=false where product_id=pid and not(id=any(ids));
 delete from public.product_images where product_id=pid;
 for item in select * from jsonb_array_elements(payload->'images') loop
  if (item->>'path') not like pid::text||'/%' or not exists(select 1 from storage.objects where bucket_id='product-images' and name=item->>'path') then raise exception 'Product image not uploaded';end if;
  insert into public.product_images(product_id,path,color,alt,position) values(pid,item->>'path',nullif(item->>'color',''),coalesce(item->>'alt',payload->>'name'),coalesce((item->>'position')::int,0));
 end loop;
 return pid;
end$$;
revoke all on function public.save_product(jsonb) from public;
grant execute on function public.save_product(jsonb) to authenticated;



-- 20260925073518 cart_checkout_reviews
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


-- 20260925073530 revoke_anon_commerce_rpcs
revoke execute on function public.add_to_cart(uuid, int) from anon;
revoke execute on function public.set_cart_quantity(uuid, int) from anon;
revoke execute on function public.remove_from_cart(uuid) from anon;
revoke execute on function public.process_checkout(jsonb, int) from anon;
revoke execute on function public.set_order_status(uuid, text) from anon;


-- 20260925080940 fix_order_items_history_rls_scope

drop policy if exists order_items_read on public.order_items;
create policy order_items_read on public.order_items
for select to authenticated
using (
  exists (
    select 1 from public.orders o
    where o.id = order_items.order_id
      and (o.user_id = auth.uid() or private.is_admin())
  )
);

drop policy if exists history_read on public.order_status_history;
create policy history_read on public.order_status_history
for select to authenticated
using (
  exists (
    select 1 from public.orders o
    where o.id = order_status_history.order_id
      and (o.user_id = auth.uid() or private.is_admin())
  )
);



-- 20260925092317 add_department_and_support_tickets

alter table public.products
  add column department text not null default 'unisex'
  check (department in ('men','women','kids','unisex'));

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  order_id uuid references public.orders(id),
  subject text not null check (length(trim(subject)) between 1 and 200),
  status text not null default 'open' check (status in ('open','in_progress','resolved','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.support_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  sender_role text not null check (sender_role in ('customer','admin')),
  sender_id uuid references auth.users(id),
  body text not null check (length(trim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);

alter table public.support_tickets enable row level security;
alter table public.support_messages enable row level security;

create policy tickets_read on public.support_tickets
for select to authenticated
using (user_id = auth.uid() or private.is_admin());

create policy tickets_admin_update on public.support_tickets
for update to authenticated
using (private.is_admin())
with check (private.is_admin());

create policy messages_read on public.support_messages
for select to authenticated
using (
  exists (select 1 from public.support_tickets t
    where t.id = support_messages.ticket_id
      and (t.user_id = auth.uid() or private.is_admin()))
);

create trigger tickets_updated before update on public.support_tickets
for each row execute function private.touch_updated_at();

create or replace function public.create_support_ticket(p_subject text, p_body text, p_order_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path to ''
as $$
declare uid uuid := auth.uid(); v_ticket_id uuid;
begin
  if uid is null then raise exception 'Authentication required' using errcode = '28000'; end if;
  if p_order_id is not null and not exists (select 1 from public.orders where id = p_order_id and user_id = uid) then
    raise exception 'Order not found';
  end if;
  insert into public.support_tickets (user_id, order_id, subject)
  values (uid, p_order_id, p_subject)
  returning id into v_ticket_id;
  insert into public.support_messages (ticket_id, sender_role, sender_id, body)
  values (v_ticket_id, 'customer', uid, p_body);
  return v_ticket_id;
end;
$$;

create or replace function public.add_support_message(p_ticket_id uuid, p_body text)
returns void
language plpgsql
security definer
set search_path to ''
as $$
declare uid uuid := auth.uid(); is_owner boolean; is_adm boolean := private.is_admin();
begin
  if uid is null then raise exception 'Authentication required' using errcode = '28000'; end if;
  select exists(select 1 from public.support_tickets where id = p_ticket_id and user_id = uid) into is_owner;
  if not is_owner and not is_adm then raise exception 'Ticket not found'; end if;
  insert into public.support_messages (ticket_id, sender_role, sender_id, body)
  values (p_ticket_id, case when is_adm then 'admin' else 'customer' end, uid, p_body);
  if is_adm then
    update public.support_tickets set status = 'in_progress' where id = p_ticket_id and status = 'open';
  else
    update public.support_tickets set status = 'open' where id = p_ticket_id and status = 'resolved';
  end if;
end;
$$;

create or replace function public.set_ticket_status(p_ticket_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path to ''
as $$
begin
  if not private.is_admin() then raise exception 'Admin access required' using errcode = '42501'; end if;
  if p_status not in ('open','in_progress','resolved','closed') then raise exception 'Invalid status'; end if;
  update public.support_tickets set status = p_status where id = p_ticket_id;
  if not found then raise exception 'Ticket not found'; end if;
end;
$$;



-- 20260925092330 save_product_department

create or replace function public.save_product(payload jsonb)
returns uuid
language plpgsql
set search_path to ''
as $function$
declare pid uuid=(payload->>'id')::uuid; item jsonb; vid uuid; ids uuid[]='{}';
begin
 if not private.is_admin() then raise exception 'Admin access required' using errcode='42501';end if;
 if jsonb_array_length(payload->'variants')<1 then raise exception 'Add at least one variant';end if;
 if payload->>'status'='published' and jsonb_array_length(payload->'images')<1 then raise exception 'Upload at least one image before publishing';end if;
 insert into public.products(id,name,description,care,price_cents,category_id,status,featured,department)
 values(pid,trim(payload->>'name'),coalesce(payload->>'description',''),coalesce(payload->>'care',''),(payload->>'price_cents')::int,nullif(payload->>'category_id','')::uuid,payload->>'status',coalesce((payload->>'featured')::boolean,false),coalesce(nullif(payload->>'department',''),'unisex'))
 on conflict(id) do update set name=excluded.name,description=excluded.description,care=excluded.care,price_cents=excluded.price_cents,category_id=excluded.category_id,status=excluded.status,featured=excluded.featured,department=excluded.department;
 for item in select * from jsonb_array_elements(payload->'variants') loop
  vid=coalesce(nullif(item->>'id','')::uuid,gen_random_uuid());
  if exists(select 1 from public.product_variants where id=vid and product_id<>pid) then raise exception 'Variant belongs to another product';end if;
  insert into public.product_variants(id,product_id,color,color_hex,size,stock,active)
  values(vid,pid,trim(item->>'color'),item->>'color_hex',trim(item->>'size'),(item->>'stock')::int,true)
  on conflict(id) do update set color=excluded.color,color_hex=excluded.color_hex,size=excluded.size,stock=excluded.stock,active=true;
  ids=array_append(ids,vid);
 end loop;
 update public.product_variants set active=false where product_id=pid and not(id=any(ids));
 delete from public.product_images where product_id=pid;
 for item in select * from jsonb_array_elements(payload->'images') loop
  if (item->>'path') not like pid::text||'/%' or not exists(select 1 from storage.objects where bucket_id='product-images' and name=item->>'path') then raise exception 'Product image not uploaded';end if;
  insert into public.product_images(product_id,path,color,alt,position) values(pid,item->>'path',nullif(item->>'color',''),coalesce(item->>'alt',payload->>'name'),coalesce((item->>'position')::int,0));
 end loop;
 return pid;
end$function$;



-- 20260925163156 repair_commerce_and_review_workflows
-- Repairs against the existing cloth-web schema. No users or catalog data are seeded.
CREATE OR REPLACE FUNCTION private.change_cart(p_variant_id uuid, p_quantity integer, p_operation text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  uid uuid := auth.uid();
  available integer;
  current_quantity integer;
  desired integer;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  INSERT INTO public.carts(user_id) VALUES(uid) ON CONFLICT DO NOTHING;
  PERFORM 1 FROM public.carts c WHERE c.user_id=uid FOR UPDATE;
  IF p_operation='remove' THEN
    DELETE FROM public.cart_items ci WHERE ci.user_id=uid AND ci.variant_id=p_variant_id;
    RETURN;
  END IF;
  IF p_operation NOT IN ('add','set') OR p_quantity IS NULL OR p_quantity<1 OR p_quantity>99 THEN
    RAISE EXCEPTION 'Quantity must be between 1 and 99' USING ERRCODE='22023';
  END IF;
  SELECT pv.stock INTO available FROM public.product_variants pv
  JOIN public.products p ON p.id=pv.product_id
  WHERE pv.id=p_variant_id AND pv.active AND p.status='published' FOR SHARE OF p,pv;
  IF NOT FOUND THEN RAISE EXCEPTION 'This product is no longer available'; END IF;
  SELECT ci.quantity INTO current_quantity FROM public.cart_items ci WHERE ci.user_id=uid AND ci.variant_id=p_variant_id;
  IF p_operation='set' AND NOT FOUND THEN RAISE EXCEPTION 'Cart item not found'; END IF;
  desired := CASE WHEN p_operation='add' THEN coalesce(current_quantity,0)+p_quantity ELSE p_quantity END;
  IF desired>99 OR desired>available THEN RAISE EXCEPTION 'Requested quantity exceeds available stock' USING ERRCODE='23514'; END IF;
  INSERT INTO public.cart_items(user_id,variant_id,quantity) VALUES(uid,p_variant_id,desired)
  ON CONFLICT(user_id,variant_id) DO UPDATE SET quantity=excluded.quantity;
END $$;
REVOKE ALL ON FUNCTION private.change_cart(uuid,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.change_cart(uuid,integer,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.add_to_cart(p_variant_id uuid,p_quantity integer)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT private.change_cart($1,$2,'add'); $$;
CREATE OR REPLACE FUNCTION public.set_cart_quantity(p_variant_id uuid,p_quantity integer)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT private.change_cart($1,$2,'set'); $$;
CREATE OR REPLACE FUNCTION public.remove_from_cart(p_variant_id uuid)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT private.change_cart($1,NULL,'remove'); $$;
REVOKE ALL ON FUNCTION public.add_to_cart(uuid,integer),public.set_cart_quantity(uuid,integer),public.remove_from_cart(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.add_to_cart(uuid,integer),public.set_cart_quantity(uuid,integer),public.remove_from_cart(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION private.checkout_impl(p_shipping jsonb,p_shipping_cents integer,p_request_id uuid)
RETURNS TABLE(order_id uuid,order_number bigint,total_cents bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  uid uuid := auth.uid();
  new_order_id uuid;
  new_order_number bigint;
  subtotal bigint;
  address jsonb;
  item record;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'Checkout request ID is required' USING ERRCODE='22023'; END IF;
  IF coalesce(p_shipping_cents,0)<>0 THEN RAISE EXCEPTION 'Shipping is free; the delivery charge cannot be overridden' USING ERRCODE='22023'; END IF;
  INSERT INTO public.carts(user_id) VALUES(uid) ON CONFLICT DO NOTHING;
  -- The same cart lock is taken by all three cart mutations.
  PERFORM 1 FROM public.carts c WHERE c.user_id=uid FOR UPDATE;
  RETURN QUERY SELECT o.id,o.order_number,o.total_cents FROM public.orders o WHERE o.user_id=uid AND o.request_id=p_request_id;
  IF FOUND THEN RETURN; END IF;

  IF p_shipping IS NULL OR jsonb_typeof(p_shipping)<>'object' THEN RAISE EXCEPTION 'Enter a shipping address'; END IF;
  IF length(btrim(coalesce(p_shipping->>'full_name',''))) NOT BETWEEN 1 AND 150
     OR length(btrim(coalesce(p_shipping->>'line1',''))) NOT BETWEEN 1 AND 300
     OR length(btrim(coalesce(p_shipping->>'city',''))) NOT BETWEEN 1 AND 150
     OR length(btrim(coalesce(p_shipping->>'country',''))) NOT BETWEEN 1 AND 100
     OR length(coalesce(p_shipping->>'postal_code',''))>20 OR length(coalesce(p_shipping->>'phone',''))>30 THEN
    RAISE EXCEPTION 'Enter a valid name, street address, city and country' USING ERRCODE='22023';
  END IF;
  address:=jsonb_build_object('full_name',btrim(p_shipping->>'full_name'),'line1',btrim(p_shipping->>'line1'),
    'city',btrim(p_shipping->>'city'),'country',btrim(p_shipping->>'country'),
    'postal_code',btrim(coalesce(p_shipping->>'postal_code','')),'phone',btrim(coalesce(p_shipping->>'phone','')));
  IF NOT EXISTS(SELECT 1 FROM public.cart_items ci WHERE ci.user_id=uid) THEN RAISE EXCEPTION 'Your bag is empty'; END IF;
  -- Freeze prices/publication state, then lock variant stock in a consistent order.
  PERFORM p.id FROM public.products p WHERE p.id IN (
    SELECT pv.product_id FROM public.product_variants pv JOIN public.cart_items ci ON ci.variant_id=pv.id WHERE ci.user_id=uid
  ) ORDER BY p.id FOR SHARE;
  PERFORM pv.id FROM public.product_variants pv JOIN public.cart_items ci ON ci.variant_id=pv.id
  WHERE ci.user_id=uid ORDER BY pv.id FOR UPDATE OF pv;
  FOR item IN SELECT ci.quantity,pv.stock,pv.active,p.status FROM public.cart_items ci
    JOIN public.product_variants pv ON pv.id=ci.variant_id JOIN public.products p ON p.id=pv.product_id WHERE ci.user_id=uid
  LOOP
    IF NOT item.active OR item.status<>'published' THEN RAISE EXCEPTION 'A piece in your bag is no longer available'; END IF;
    IF item.stock<item.quantity THEN RAISE EXCEPTION 'Insufficient stock for one or more items' USING ERRCODE='23514'; END IF;
  END LOOP;
  SELECT sum(p.price_cents::bigint*ci.quantity) INTO subtotal FROM public.cart_items ci
  JOIN public.product_variants pv ON pv.id=ci.variant_id JOIN public.products p ON p.id=pv.product_id WHERE ci.user_id=uid;
  INSERT INTO public.orders AS o(user_id,request_id,status,payment_status,subtotal_cents,shipping_cents,total_cents,shipping_address)
  VALUES(uid,p_request_id,'pending','unpaid',subtotal,0,subtotal,address)
  RETURNING o.id,o.order_number INTO new_order_id,new_order_number;
  INSERT INTO public.order_items(order_id,variant_id,product_name,color,size,image_path,unit_price_cents,quantity)
  SELECT new_order_id,pv.id,p.name,pv.color,pv.size,
    (SELECT im.path FROM public.product_images im WHERE im.product_id=p.id ORDER BY (lower(im.color)=lower(pv.color)) DESC NULLS LAST,im.position LIMIT 1),
    p.price_cents,ci.quantity FROM public.cart_items ci JOIN public.product_variants pv ON pv.id=ci.variant_id
    JOIN public.products p ON p.id=pv.product_id WHERE ci.user_id=uid;
  UPDATE public.product_variants pv SET stock=pv.stock-ci.quantity FROM public.cart_items ci WHERE ci.variant_id=pv.id AND ci.user_id=uid;
  INSERT INTO public.order_status_history(order_id,status) VALUES(new_order_id,'pending');
  DELETE FROM public.cart_items ci WHERE ci.user_id=uid;
  RETURN QUERY SELECT new_order_id,new_order_number,subtotal;
END $$;
REVOKE ALL ON FUNCTION private.checkout_impl(jsonb,integer,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.checkout_impl(jsonb,integer,uuid) TO authenticated;

-- Backward-compatible entry point for the previous frontend.
CREATE OR REPLACE FUNCTION public.process_checkout(shipping jsonb,shipping_cents integer DEFAULT 0)
RETURNS TABLE(order_id uuid,order_number bigint,total_cents bigint)
LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT * FROM private.checkout_impl($1,$2,gen_random_uuid()); $$;
CREATE OR REPLACE FUNCTION public.checkout_order(p_shipping jsonb,p_request_id uuid)
RETURNS TABLE(order_id uuid,order_number bigint,total_cents bigint)
LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT * FROM private.checkout_impl($1,0,$2); $$;
REVOKE ALL ON FUNCTION public.process_checkout(jsonb,integer),public.checkout_order(jsonb,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.process_checkout(jsonb,integer),public.checkout_order(jsonb,uuid) TO authenticated;

ALTER POLICY reviews_insert_own ON public.reviews WITH CHECK ((SELECT auth.uid())=user_id AND approved=false);
ALTER POLICY reviews_admin_update ON public.reviews USING ((SELECT private.is_admin())) WITH CHECK ((SELECT private.is_admin()));

CREATE OR REPLACE FUNCTION private.update_order_status(p_order_id uuid,p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE current_status text;
BEGIN
  IF auth.uid() IS NULL OR NOT private.is_admin() THEN RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501'; END IF;
  IF p_status IS NULL OR p_status NOT IN ('pending','confirmed','processing','shipped','delivered','cancelled') THEN RAISE EXCEPTION 'Invalid status'; END IF;
  SELECT o.status INTO current_status FROM public.orders o WHERE o.id=p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found'; END IF;
  IF current_status=p_status THEN RETURN; END IF;
  IF current_status IN ('cancelled','delivered') THEN RAISE EXCEPTION 'This order is already closed'; END IF;
  IF p_status='cancelled' THEN
    IF current_status='shipped' THEN RAISE EXCEPTION 'A shipped order cannot be cancelled; contact the customer about a return'; END IF;
    PERFORM pv.id FROM public.product_variants pv WHERE pv.id IN (SELECT oi.variant_id FROM public.order_items oi WHERE oi.order_id=p_order_id) ORDER BY pv.id FOR UPDATE;
    UPDATE public.product_variants pv SET stock=pv.stock+x.quantity FROM (
      SELECT oi.variant_id,sum(oi.quantity)::integer AS quantity FROM public.order_items oi WHERE oi.order_id=p_order_id GROUP BY oi.variant_id
    ) x WHERE pv.id=x.variant_id;
  ELSIF array_position(ARRAY['pending','confirmed','processing','shipped','delivered'],p_status)
      <=array_position(ARRAY['pending','confirmed','processing','shipped','delivered'],current_status) THEN
    RAISE EXCEPTION 'Order status can only move forward';
  END IF;
  UPDATE public.orders o SET status=p_status WHERE o.id=p_order_id;
  INSERT INTO public.order_status_history(order_id,status) VALUES(p_order_id,p_status);
END $$;
CREATE OR REPLACE FUNCTION public.set_order_status(p_order_id uuid,p_status text)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT private.update_order_status($1,$2); $$;
REVOKE ALL ON FUNCTION private.update_order_status(uuid,text),public.set_order_status(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.update_order_status(uuid,text),public.set_order_status(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION private.record_payment_status(p_order_id uuid,p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE old_status text; order_status text;
BEGIN
  IF auth.uid() IS NULL OR NOT private.is_admin() THEN RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501'; END IF;
  IF p_status IS NULL OR p_status NOT IN ('unpaid','paid','refunded') THEN RAISE EXCEPTION 'Invalid payment status'; END IF;
  SELECT o.payment_status,o.status INTO old_status,order_status FROM public.orders o WHERE o.id=p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found'; END IF;
  IF old_status=p_status THEN RETURN; END IF;
  IF p_status='paid' AND order_status='cancelled' THEN RAISE EXCEPTION 'Cannot mark a cancelled order as paid'; END IF;
  IF p_status='refunded' AND old_status<>'paid' THEN RAISE EXCEPTION 'Only a paid order can be marked refunded'; END IF;
  IF p_status='unpaid' AND old_status='refunded' THEN RAISE EXCEPTION 'A refunded payment cannot be marked unpaid'; END IF;
  UPDATE public.orders o SET payment_status=p_status WHERE o.id=p_order_id;
  INSERT INTO public.admin_notes(order_id,note) VALUES(p_order_id,'Payment recorded as '||p_status||' by admin '||auth.uid()::text);
END $$;
CREATE OR REPLACE FUNCTION public.set_payment_status(p_order_id uuid,p_status text)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT private.record_payment_status($1,$2); $$;
REVOKE ALL ON FUNCTION private.record_payment_status(uuid,text),public.set_payment_status(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.record_payment_status(uuid,text),public.set_payment_status(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION private.create_ticket(p_subject text,p_body text,p_order_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid:=auth.uid(); tid uuid;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_order_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.orders o WHERE o.id=p_order_id AND o.user_id=uid) THEN
    RAISE EXCEPTION 'Order not found' USING ERRCODE='42501';
  END IF;
  INSERT INTO public.support_tickets(user_id,order_id,subject) VALUES(uid,p_order_id,btrim(p_subject)) RETURNING id INTO tid;
  INSERT INTO public.support_messages(ticket_id,sender_role,sender_id,body) VALUES(tid,'customer',uid,btrim(p_body));
  RETURN tid;
END $$;
CREATE OR REPLACE FUNCTION private.reply_to_ticket(p_ticket_id uuid,p_body text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE uid uuid:=auth.uid(); is_adm boolean:=private.is_admin(); ticket public.support_tickets%ROWTYPE;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  SELECT t.* INTO ticket FROM public.support_tickets t WHERE t.id=p_ticket_id FOR UPDATE;
  IF NOT FOUND OR (ticket.user_id<>uid AND NOT is_adm) THEN RAISE EXCEPTION 'Ticket not found' USING ERRCODE='42501'; END IF;
  INSERT INTO public.support_messages(ticket_id,sender_role,sender_id,body)
  VALUES(p_ticket_id,CASE WHEN is_adm THEN 'admin' ELSE 'customer' END,uid,btrim(p_body));
  UPDATE public.support_tickets SET status=CASE WHEN is_adm AND status='open' THEN 'in_progress'
    WHEN NOT is_adm AND status IN ('resolved','closed') THEN 'open' ELSE status END,updated_at=now() WHERE id=p_ticket_id;
END $$;
CREATE OR REPLACE FUNCTION private.update_ticket_status(p_ticket_id uuid,p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT private.is_admin() THEN RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501'; END IF;
  IF p_status IS NULL OR p_status NOT IN ('open','in_progress','resolved','closed') THEN RAISE EXCEPTION 'Invalid status' USING ERRCODE='22023'; END IF;
  UPDATE public.support_tickets SET status=p_status WHERE id=p_ticket_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Ticket not found'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.create_support_ticket(p_subject text,p_body text,p_order_id uuid DEFAULT NULL)
RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT private.create_ticket($1,$2,$3); $$;
CREATE OR REPLACE FUNCTION public.add_support_message(p_ticket_id uuid,p_body text)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT private.reply_to_ticket($1,$2); $$;
CREATE OR REPLACE FUNCTION public.set_ticket_status(p_ticket_id uuid,p_status text)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$ SELECT private.update_ticket_status($1,$2); $$;
REVOKE ALL ON FUNCTION private.create_ticket(text,text,uuid),private.reply_to_ticket(uuid,text),private.update_ticket_status(uuid,text),
  public.create_support_ticket(text,text,uuid),public.add_support_message(uuid,text),public.set_ticket_status(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.create_ticket(text,text,uuid),private.reply_to_ticket(uuid,text),private.update_ticket_status(uuid,text),
  public.create_support_ticket(text,text,uuid),public.add_support_message(uuid,text),public.set_ticket_status(uuid,text) TO authenticated;
NOTIFY pgrst,'reload schema';



-- 20260927143117 add_category_images_storage
-- Storage-only change for the existing cloth-web project.
-- Preserve product-images, application tables, auth, and all existing data.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'category-images',
  'category-images',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
);

create policy category_images_public_read
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'category-images');

create policy category_images_admin_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'category-images'
  and (select private.is_admin())
);

create policy category_images_admin_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'category-images'
  and (select private.is_admin())
)
with check (
  bucket_id = 'category-images'
  and (select private.is_admin())
);

create policy category_images_admin_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'category-images'
  and (select private.is_admin())
);


-- 20260927144712 add_category_image_columns
-- User-approved addition of the three category fields expected by the frontend.
-- Preserve existing columns, rows, RLS policies, buckets, and all other tables.
set local lock_timeout = '5s';
set local statement_timeout = '30s';

alter table public.categories
  add column image_path text,
  add column image_alt text not null default '',
  add column display_order integer not null default 0
    constraint categories_display_order_check check (display_order >= 0);

notify pgrst, 'reload schema';


-- 20260927152444 extend_dynamic_category_management
-- Extend the existing categories table only; preserve its upload-path contract.
set local lock_timeout = '5s';
set local statement_timeout = '30s';

alter table public.categories
  add column description text not null default '',
  add column image_url text generated always as (
    case
      when image_path is null or image_path = '' then null
      else 'https://oapkgdvsnpakpackmgcs.supabase.co/storage/v1/object/public/category-images/' || image_path
    end
  ) stored,
  add column is_active boolean not null default true,
  add column updated_at timestamptz not null default now();

comment on column public.categories.image_url is
  'Read-only public URL generated from image_path. Upload to category-images and write image_path to set or replace an image.';

create trigger categories_updated
before update on public.categories
for each row execute function private.touch_updated_at();

alter policy categories_read
on public.categories
to anon, authenticated
using (is_active);

notify pgrst, 'reload schema';


-- 20260927163601 separate_accessory_and_collection_categories
-- Separate the two category groups without duplicating product data.
set local lock_timeout = '5s';
set local statement_timeout = '30s';

alter table public.categories
  add column is_accessory boolean not null default false;

comment on column public.categories.is_accessory is
  'false: Collections section/admin. true: Accessories section/admin. Both use the existing category-images storage and products.category_id relationship.';

-- Move only the explicitly requested, existing Accessories category.
update public.categories
set is_accessory = true
where slug = 'accessories' and name = 'Accessories';

notify pgrst, 'reload schema';


-- 20260928064458 extend_reviews_moderation_spam_and_ratings

-- Maison Elan: review-only extension. Preserve legacy approved callers.
alter table public.reviews
  add column customer_name text not null default 'Customer',
  add column status text not null default 'pending',
  add column is_spam boolean not null default false,
  add column updated_at timestamptz not null default now();

update public.reviews r
set customer_name = coalesce(
      (select nullif(btrim(p.full_name), '') from public.profiles p where p.id = r.user_id),
      'Customer'),
    status = case when r.approved then 'approved' else 'pending' end,
    updated_at = r.created_at;

alter table public.reviews
  alter column user_id set default auth.uid(),
  add constraint reviews_status_check
    check (status in ('pending','approved','rejected','spam')),
  add constraint reviews_moderation_consistency_check
    check (approved = (status = 'approved') and is_spam = (status = 'spam')),
  drop constraint reviews_product_id_user_id_key;

-- Composite index covers product_id lookups and duplicate detection.
create index reviews_product_user_idx on public.reviews (product_id, user_id);
create index reviews_user_id_idx on public.reviews (user_id);
create index reviews_status_idx on public.reviews (status);
create index reviews_is_spam_idx on public.reviews (is_spam);

create function private.guard_review_submission()
returns trigger
language plpgsql volatile security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_duplicate boolean;
begin
  if v_user_id is null or new.user_id is distinct from v_user_id then
    raise exception 'Sign in and submit reviews only for your own account.' using errcode = '42501';
  end if;
  if new.status is distinct from 'pending' or new.approved is distinct from false
     or new.is_spam is distinct from false then
    raise exception 'Review moderation is controlled by an administrator.' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.products p
    where p.id = new.product_id and (p.status = 'published' or private.is_admin())
  ) then
    raise exception 'Product is not available for review.' using errcode = '22023';
  end if;
  -- The API uses READ COMMITTED. Reject stale-snapshot submission transactions.
  if current_setting('transaction_isolation') not in ('read committed','read uncommitted') then
    raise exception 'Submit reviews in a READ COMMITTED transaction.' using errcode = '40001';
  end if;
  -- Serialize only this customer's submissions for this product.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('maison-elan:review:' || new.product_id::text || ':' || v_user_id::text, 0)
  );
  select exists (
    select 1 from public.reviews r
    where r.product_id = new.product_id and r.user_id = v_user_id
  ) into v_duplicate;

  new.customer_name := coalesce(
    (select nullif(btrim(p.full_name), '') from public.profiles p where p.id = v_user_id),
    'Customer');
  new.is_spam := v_duplicate;
  new.status := case when v_duplicate then 'spam' else 'pending' end;
  new.approved := false;
  new.created_at := clock_timestamp();
  new.updated_at := new.created_at;
  return new;
end
$function$;

create function private.guard_review_moderation()
returns trigger
language plpgsql volatile security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Only administrators can moderate reviews.' using errcode = '42501';
  end if;
  if new.id is distinct from old.id
     or new.product_id is distinct from old.product_id
     or new.user_id is distinct from old.user_id
     or new.customer_name is distinct from old.customer_name
     or new.rating is distinct from old.rating
     or new.comment is distinct from old.comment
     or new.created_at is distinct from old.created_at then
    raise exception 'Review content and ownership cannot be changed during moderation.' using errcode = '42501';
  end if;

  if new.status is distinct from old.status then
    -- Explicit status is authoritative.
    null;
  elsif new.approved is distinct from old.approved then
    -- Compatibility with the existing admin approve/hide toggle.
    new.status := case when new.approved then 'approved' else 'rejected' end;
  end if;
  new.approved := (new.status = 'approved');
  new.is_spam := (new.status = 'spam');
  new.updated_at := clock_timestamp();
  return new;
end
$function$;

revoke all on function private.guard_review_submission() from public, anon, authenticated, service_role;
revoke all on function private.guard_review_moderation() from public, anon, authenticated, service_role;

create trigger reviews_before_insert
before insert on public.reviews
for each row execute function private.guard_review_submission();

create trigger reviews_before_update
before update on public.reviews
for each row execute function private.guard_review_moderation();

alter table public.reviews enable row level security;
drop policy reviews_read on public.reviews;
drop policy reviews_insert_own on public.reviews;
drop policy reviews_admin_update on public.reviews;
drop policy reviews_admin_delete on public.reviews;

create policy reviews_read on public.reviews
for select to anon, authenticated
using (status = 'approved' or (select private.is_admin()));

create policy reviews_insert_own on public.reviews
for insert to authenticated
with check (
  user_id = (select auth.uid())
  and status in ('pending','spam')
  and approved = false
  and is_spam = (status = 'spam')
);

create policy reviews_admin_update on public.reviews
for update to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy reviews_admin_delete_spam on public.reviews
for delete to authenticated
using (status = 'spam' and is_spam and (select private.is_admin()));

revoke all on table public.reviews from public, anon, authenticated;
grant select on table public.reviews to anon, authenticated;
grant insert (product_id, user_id, rating, comment, approved)
  on public.reviews to authenticated;
grant update (status, approved) on public.reviews to authenticated;
grant delete on table public.reviews to authenticated;

-- A receipt for this submission, without giving customers SELECT access to pending reviews.
create function private.submit_review(p_product_id uuid, p_rating integer, p_comment text default '')
returns table (review_id uuid, status text, is_spam boolean)
language plpgsql volatile security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null then
    raise exception 'Sign in to submit a review.' using errcode = '42501';
  end if;
  return query
    insert into public.reviews as r (product_id, user_id, rating, comment)
    values (p_product_id, auth.uid(), p_rating, btrim(coalesce(p_comment, '')))
    returning r.id, r.status, r.is_spam;
end
$function$;

create function public.submit_review(p_product_id uuid, p_rating integer, p_comment text default '')
returns table (review_id uuid, status text, is_spam boolean)
language sql volatile security invoker
set search_path = ''
as $function$
  select * from private.submit_review(p_product_id, p_rating, p_comment);
$function$;

revoke all on function private.submit_review(uuid, integer, text) from public, anon, authenticated, service_role;
revoke all on function public.submit_review(uuid, integer, text) from public, anon, authenticated, service_role;
grant execute on function private.submit_review(uuid, integer, text) to authenticated;
grant execute on function public.submit_review(uuid, integer, text) to authenticated;

create view public.product_review_stats
with (security_invoker = true, security_barrier = true)
as
select p.id as product_id,
       avg(r.rating) as average_rating,
       count(r.id) as review_count
from public.products p
left join public.reviews r
  on r.product_id = p.id and r.status = 'approved'
group by p.id;

revoke all on table public.product_review_stats from public, anon, authenticated;
grant select on table public.product_review_stats to anon, authenticated, service_role;

comment on column public.reviews.customer_name is 'Public display name captured from the customer profile at submission; no email is exposed.';
comment on column public.reviews.approved is 'Legacy compatibility flag, synchronized with status by review triggers.';
comment on column public.reviews.is_spam is 'True while status is spam. Admin approval or rejection reclassifies the review.';
comment on view public.product_review_stats is 'Live approved-only averages and counts. Unrated visible products have NULL average_rating and zero review_count. Uses caller RLS.';
comment on function public.submit_review(uuid, integer, text) is 'Authenticated review submission; returns only the receipt for the new review. Duplicate submissions are retained with spam status.';

notify pgrst, 'reload schema';



-- 20260928073309 add_customer_support_requests

create table public.support_requests (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  customer_email text not null,
  customer_phone text not null,
  subject text not null,
  message text not null,
  status text not null default 'new',
  admin_note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint support_requests_name_check
    check (char_length(btrim(customer_name)) between 1 and 120),
  constraint support_requests_email_check
    check (char_length(customer_email) between 3 and 254
      and customer_email ~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'),
  constraint support_requests_phone_check
    check (char_length(btrim(customer_phone)) between 1 and 40),
  constraint support_requests_subject_check
    check (char_length(btrim(subject)) between 1 and 200),
  constraint support_requests_message_check
    check (char_length(btrim(message)) between 1 and 10000),
  constraint support_requests_status_check
    check (status in ('new','in_progress','resolved','closed')),
  constraint support_requests_note_check
    check (char_length(admin_note) <= 10000)
);

create index support_requests_status_idx on public.support_requests (status);
create index support_requests_customer_email_idx on public.support_requests (customer_email);
create index support_requests_created_at_idx on public.support_requests (created_at desc);

create function private.prepare_support_request()
returns trigger
language plpgsql security invoker
set search_path = ''
as $function$
begin
  if tg_op = 'INSERT' then
    new.customer_name := btrim(new.customer_name);
    new.customer_email := lower(btrim(new.customer_email));
    new.customer_phone := btrim(new.customer_phone);
    new.subject := btrim(new.subject);
    new.message := btrim(new.message);
    new.created_at := clock_timestamp();
    new.updated_at := new.created_at;
  else
    new.updated_at := clock_timestamp();
  end if;
  return new;
end
$function$;

revoke all on function private.prepare_support_request()
  from public, anon, authenticated, service_role;

create trigger support_requests_prepare
before insert or update on public.support_requests
for each row execute function private.prepare_support_request();

alter table public.support_requests enable row level security;

create policy support_requests_public_insert
on public.support_requests for insert to anon, authenticated
with check (status = 'new' and admin_note = '');

create policy support_requests_admin_read
on public.support_requests for select to authenticated
using ((select private.is_admin()));

create policy support_requests_admin_update
on public.support_requests for update to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy support_requests_admin_delete
on public.support_requests for delete to authenticated
using ((select private.is_admin()));

revoke all on table public.support_requests from public, anon, authenticated;
grant insert (customer_name, customer_email, customer_phone, subject, message)
  on public.support_requests to anon, authenticated;
grant select on public.support_requests to authenticated;
grant update (status, admin_note) on public.support_requests to authenticated;
grant delete on public.support_requests to authenticated;

comment on table public.support_requests is
  'Public contact-form submissions. Contact details are supplied by the submitter. Only existing allowlisted admins can read or manage requests.';
comment on column public.support_requests.admin_note is
  'Internal admin note. Never returned to public visitors or non-admin customers.';

notify pgrst, 'reload schema';



-- 20260928084410 fix_support_requests_insert_privileges

-- Expand existing support-only INSERT grants to table-level INSERT.
-- RLS still restricts every submission to status=new and an empty admin_note.
alter table public.support_requests enable row level security;
grant insert on table public.support_requests to anon, authenticated;
notify pgrst, 'reload schema';



-- 20260929094806 add_admin_get_support_requests_rpc

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



-- 20260929100050 add_admin_update_support_request_rpc

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



-- 20260929105300 add_get_my_support_replies_rpc

create function private.get_my_support_replies()
returns table (
  id uuid,
  subject text,
  message text,
  status text,
  admin_reply text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_email text;
begin
  if v_user_id is null then
    raise exception 'Authentication required.' using errcode = '42501';
  end if;

  select lower(btrim(u.email))
  into v_email
  from auth.users as u
  where u.id = v_user_id
    and u.email_confirmed_at is not null;

  if v_email is null or v_email = '' then
    return;
  end if;

  return query
    select
      r.id,
      r.subject,
      r.message,
      r.status,
      r.admin_reply,
      r.created_at,
      r.updated_at
    from public.support_requests as r
    where r.customer_email = v_email
      and btrim(r.admin_reply) <> ''
    order by r.updated_at desc, r.id desc;
end
$function$;

revoke all on function private.get_my_support_replies()
  from public, anon, authenticated, service_role;
grant execute on function private.get_my_support_replies() to authenticated;

comment on function private.get_my_support_replies() is
  'Read-only support reply projection for the caller authenticated by auth.uid(). Matches the current confirmed email from auth.users, never a client-supplied email or user_metadata. Excludes internal notes and contact details.';

create function public.get_my_support_replies()
returns table (
  id uuid,
  subject text,
  message text,
  status text,
  admin_reply text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select r.id, r.subject, r.message, r.status, r.admin_reply, r.created_at, r.updated_at
  from private.get_my_support_replies() as r;
$function$;

revoke all on function public.get_my_support_replies()
  from public, anon, authenticated, service_role;
grant execute on function public.get_my_support_replies() to authenticated;

comment on function public.get_my_support_replies() is
  'No-argument customer reply RPC. Returns only nonblank replies addressed to the signed-in account current confirmed email, newest first. Internal admin notes are never returned.';

notify pgrst, 'reload schema';



-- 20260929110022 add_support_request_user_ownership

alter table public.support_requests
  add column user_id uuid,
  add constraint support_requests_user_id_fkey
    foreign key (user_id) references auth.users(id) on delete set null;

create index support_requests_user_id_idx
  on public.support_requests (user_id);

comment on column public.support_requests.user_id is
  'Account that submitted the request, assigned from auth.uid() by the support trigger. Nullable for guest and legacy requests; clients cannot assign a different account.';

create or replace function private.prepare_support_request()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
begin
  if tg_op = 'INSERT' then
    if new.user_id is not null and new.user_id is distinct from v_user_id then
      raise exception 'Support requests can only be assigned to the signed-in account.'
        using errcode = '42501';
    end if;

    new.user_id := v_user_id;
    new.customer_name := btrim(new.customer_name);
    new.customer_email := lower(btrim(new.customer_email));
    new.customer_phone := btrim(new.customer_phone);
    new.subject := btrim(new.subject);
    new.message := btrim(new.message);
    new.created_at := clock_timestamp();
    new.updated_at := new.created_at;
  else
    new.updated_at := clock_timestamp();
  end if;
  return new;
end
$function$;

alter policy support_requests_public_insert
  on public.support_requests
  to anon, authenticated
  with check (
    status = 'new'
    and admin_note = ''
    and admin_reply = ''
    and user_id is not distinct from (select auth.uid())
  );

create or replace function private.get_my_support_replies()
returns table (
  id uuid,
  subject text,
  message text,
  status text,
  admin_reply text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
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
  end
  into v_email
  from auth.users as u
  where u.id = v_user_id;

  if not found then
    return;
  end if;

  return query
    select
      r.id,
      r.subject,
      r.message,
      r.status,
      r.admin_reply,
      r.created_at,
      r.updated_at
    from public.support_requests as r
    where (
      r.user_id = v_user_id
      or (
        r.user_id is null
        and v_email is not null
        and v_email <> ''
        and r.customer_email = v_email
      )
    )
    and btrim(r.admin_reply) <> ''
    order by r.updated_at desc, r.id desc;
end
$function$;

comment on function private.get_my_support_replies() is
  'Read-only support replies for the account recorded in user_id. Guest and legacy rows without user_id use the caller current confirmed email from auth.users. Internal notes and contact details are excluded.';

comment on function public.get_my_support_replies() is
  'No-argument customer reply RPC. Returns nonblank replies for requests owned by the signed-in account, with confirmed-email matching for guest and legacy requests only.';

notify pgrst, 'reload schema';



-- 20260929133919 add_submit_support_request_rpc

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



-- 20260929140447 add_admin_get_support_messages_rpc

create function public.admin_get_support_messages(p_support_request_id uuid)
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
  v_request public.support_requests%rowtype;
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Admin access required.' using errcode = '42501';
  end if;

  if p_support_request_id is null then
    raise exception 'Support request ID is required.' using errcode = '22023';
  end if;

  select r.* into v_request
  from public.support_requests as r
  where r.id = p_support_request_id;

  if not found then
    raise exception 'Support request not found.' using errcode = 'P0002';
  end if;

  return query
  with related_requests as (
    select r.*
    from public.support_requests as r
    where lower(btrim(r.subject)) = lower(btrim(v_request.subject))
      and r.user_id is not distinct from v_request.user_id
      and (
        v_request.user_id is not null
        or r.customer_email = v_request.customer_email
      )
  ),
  stored_messages as (
    select
      r.id as message_id,
      r.id as request_id,
      'customer'::text as sender,
      r.message as message_text,
      r.created_at as message_timestamp,
      'request_created_at'::text as time_source,
      0 as sender_order
    from related_requests as r

    union all

    select
      md5('maison-elan:support-request:admin-reply:' || r.id::text)::uuid,
      r.id,
      'admin'::text,
      r.admin_reply,
      r.updated_at,
      'request_updated_at_not_original_reply_timestamp'::text,
      1
    from related_requests as r
    where btrim(r.admin_reply) <> ''
  )
  select
    m.message_id,
    m.request_id,
    m.sender,
    m.message_text,
    m.message_timestamp,
    m.time_source
  from stored_messages as m
  order by m.message_timestamp asc, m.sender_order asc, m.message_id asc;
end
$function$;

revoke all on function public.admin_get_support_messages(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_get_support_messages(uuid) to authenticated;

comment on function public.admin_get_support_messages(uuid) is
  'Admin-only read projection of existing support request messages and current admin replies. Groups case-insensitive trimmed subjects within the same user_id, or the same email among guest/legacy rows. Does not join the older support_tickets/support_messages system or expose internal notes as messages. Admin reply IDs are deterministic projection IDs, not stored message IDs. Reply created_at uses the request last-update timestamp and is explicitly marked by timestamp_source; original reply timestamps and overwritten reply history were not stored.';

notify pgrst, 'reload schema';



-- 20260930153401 add_get_my_support_conversations_rpc

create function private.get_my_support_conversations()
returns table (
  id uuid,
  subject text,
  status text,
  message text,
  admin_reply text,
  created_at timestamptz,
  updated_at timestamptz,
  message_count bigint,
  messages jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
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
    select
      r.subject_key,
      r.id as message_id,
      r.id as request_id,
      'customer'::text as sender,
      r.message as message_text,
      r.created_at as message_timestamp,
      'request_created_at'::text as time_source,
      0 as sender_order
    from owned_requests as r

    union all

    select
      r.subject_key,
      md5('maison-elan:support-request:admin-reply:' || r.id::text)::uuid,
      r.id,
      'admin'::text,
      r.admin_reply,
      r.updated_at,
      'request_updated_at_not_original_reply_timestamp'::text,
      1
    from owned_requests as r
    where btrim(r.admin_reply) <> ''
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
$function$;

revoke all on function private.get_my_support_conversations()
  from public, anon, authenticated, service_role;
grant execute on function private.get_my_support_conversations() to authenticated;

create function public.get_my_support_conversations()
returns table (
  id uuid,
  subject text,
  status text,
  message text,
  admin_reply text,
  created_at timestamptz,
  updated_at timestamptz,
  message_count bigint,
  messages jsonb
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select
    c.id, c.subject, c.status, c.message, c.admin_reply,
    c.created_at, c.updated_at, c.message_count, c.messages
  from private.get_my_support_conversations() as c;
$function$;

revoke all on function public.get_my_support_conversations()
  from public, anon, authenticated, service_role;
grant execute on function public.get_my_support_conversations() to authenticated;

comment on function private.get_my_support_conversations() is
  'Read-only customer conversation projection. Filters by auth.uid(), with current confirmed email fallback only for guest/legacy requests without user_id, then groups trimmed case-insensitive subjects for this caller. Returns a stable earliest request UUID, latest request status/customer message, latest nonblank saved admin reply, and the available message list. Never returns internal admin notes or other accounts requests. Saved reply timestamps use request updated_at and are marked in each message timestamp_source; overwritten reply history was not stored.';

comment on function public.get_my_support_conversations() is
  'No-argument customer conversation RPC. Returns id, subject, status, message, admin_reply, created_at, updated_at, message_count and messages. Unanswered requests are included. Only authenticated callers can execute; all identity checks run in the private helper.';

notify pgrst, 'reload schema';



-- 20260930170327 add_get_my_support_messages_rpc

create function public.get_my_support_messages(p_conversation_id uuid)
returns table (
  id uuid,
  conversation_id uuid,
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
  v_messages jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.' using errcode = '42501';
  end if;

  if p_conversation_id is null then
    raise exception 'Support conversation ID is required.' using errcode = '22023';
  end if;

  select c.messages into v_messages
  from public.get_my_support_conversations() as c
  where c.id = p_conversation_id;

  if not found then
    raise exception 'Support conversation not found or unavailable.' using errcode = 'P0002';
  end if;

  return query
  select
    m.id,
    p_conversation_id,
    m.support_request_id,
    m.sender_type,
    m.message,
    m.created_at,
    m.timestamp_source
  from pg_catalog.jsonb_array_elements(v_messages) with ordinality as e(value, position)
  cross join lateral pg_catalog.jsonb_to_record(e.value) as m(
    id uuid,
    support_request_id uuid,
    sender_type text,
    message text,
    created_at timestamptz,
    timestamp_source text
  )
  order by e.position;
end;
$function$;

revoke execute on function public.get_my_support_messages(uuid)
from public, anon, authenticated, service_role;
grant execute on function public.get_my_support_messages(uuid) to authenticated;

comment on function public.get_my_support_messages(uuid) is
'Read-only messages for a canonical conversation ID returned by get_my_support_conversations(). Reuses its caller ownership checks and ordering. Includes stored customer messages and current saved admin replies only; no internal notes. Admin reply timestamps are request updated_at, not original send timestamps.';

notify pgrst, 'reload schema';



-- 20260930172815 add_send_customer_support_message_rpc

create function private.get_customer_support_sender()
returns table (
  customer_name text,
  customer_email text,
  customer_phone text
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_auth_phone text;
  v_profile_name text;
  v_saved_name text;
  v_saved_phone text;
begin
  if v_user_id is null then
    raise exception 'Authentication required.' using errcode = '42501';
  end if;

  select lower(btrim(u.email)),
    case when u.phone_confirmed_at is not null then nullif(btrim(u.phone), '') else null end
  into v_email, v_auth_phone
  from auth.users as u
  where u.id = v_user_id;

  if not found then
    raise exception 'Signed-in account not found.' using errcode = '42501';
  end if;
  if v_email is null or v_email = '' then
    raise exception 'An email account is required to contact support.' using errcode = '22023';
  end if;

  select nullif(btrim(p.full_name), '') into v_profile_name
  from public.profiles as p
  where p.id = v_user_id;

  select nullif(btrim(r.customer_name), ''),
         nullif(nullif(btrim(r.customer_phone), ''), 'Not provided')
  into v_saved_name, v_saved_phone
  from public.support_requests as r
  where r.user_id = v_user_id
  order by r.created_at desc, r.id desc
  limit 1;

  return query
  select left(coalesce(v_profile_name, v_saved_name, v_email), 120),
         v_email,
         coalesce(v_auth_phone, v_saved_phone, 'Not provided');
end;
$function$;

revoke execute on function private.get_customer_support_sender()
from public, anon, authenticated, service_role;
grant execute on function private.get_customer_support_sender() to authenticated;

comment on function private.get_customer_support_sender() is
'Support-only identity lookup for auth.uid(): current database login email, own profile or saved contact name, confirmed account phone or own saved support phone. The literal Not provided denotes an absent phone number; user-editable JWT claims and other accounts are never used.';

create function public.send_customer_support_message(p_message text)
returns uuid
language plpgsql
volatile
security invoker
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_message text := btrim(p_message);
  v_sender record;
  v_request_id uuid;
  v_conversation_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required.' using errcode = '42501';
  end if;
  if v_message is null or char_length(v_message) < 1 or char_length(v_message) > 10000 then
    raise exception 'Message must contain between 1 and 10000 characters.' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('maison-elan:customer-support-send:' || v_user_id::text, 0)
  );

  select s.* into v_sender from private.get_customer_support_sender() as s;

  v_request_id := public.submit_support_request(
    p_customer_email => v_sender.customer_email,
    p_customer_name => v_sender.customer_name,
    p_customer_phone => v_sender.customer_phone,
    p_message => v_message,
    p_subject => 'Customer Support'
  );

  select c.id into v_conversation_id
  from public.get_my_support_conversations() as c
  where lower(btrim(c.subject)) = 'customer support';

  if not found then
    raise exception 'Support conversation could not be retrieved.' using errcode = 'P0002';
  end if;

  return v_conversation_id;
end;
$function$;

revoke execute on function public.send_customer_support_message(text)
from public, anon, authenticated, service_role;
grant execute on function public.send_customer_support_message(text) to authenticated;

comment on function public.send_customer_support_message(text) is
'Signed-in message-only contact endpoint. Inserts a new request through submit_support_request with subject Customer Support and own server-resolved contact identity; repeated messages group into the same normalized-subject conversation. Returns its canonical UUID for get_my_support_messages(p_conversation_id). Never overwrites previous requests, replies, or notes.';

notify pgrst, 'reload schema';



-- 20260930174153 add_ensure_customer_profile_rpc

create function private.ensure_customer_profile()
returns setof public.profiles
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_metadata jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication required.' using errcode = '42501';
  end if;

  select u.raw_user_meta_data into v_metadata
  from auth.users as u
  where u.id = v_user_id;
  if not found then
    raise exception 'Signed-in account not found.' using errcode = '42501';
  end if;

  insert into public.profiles (id, full_name)
  values (
    v_user_id,
    left(coalesce(v_metadata ->> 'full_name', ''), 150)
  )
  on conflict (id) do nothing;

  return query
  select p.*
  from public.profiles as p
  where p.id = v_user_id;

  if not found then
    raise exception 'Customer profile is unavailable.' using errcode = '42501';
  end if;
end;
$function$;

revoke execute on function private.ensure_customer_profile()
from public, anon, authenticated, service_role;
grant execute on function private.ensure_customer_profile() to authenticated;

comment on function private.ensure_customer_profile() is
'Ensures only auth.uid() has a profile, after checking the current auth.users record exists. Existing profiles are returned without updates. A missing profile uses the same full_name initialization as the existing signup trigger. Metadata is used only as display text, never for ownership or privileges. Does not create carts, wishlists, users or memberships.';

create function public.ensure_customer_profile()
returns setof public.profiles
language sql
volatile
security invoker
set search_path = ''
as $function$
  select p.id, p.full_name, p.created_at, p.updated_at
  from private.ensure_customer_profile() as p;
$function$;

revoke execute on function public.ensure_customer_profile()
from public, anon, authenticated, service_role;
grant execute on function public.ensure_customer_profile() to authenticated;

comment on function public.ensure_customer_profile() is
'No-argument authenticated API endpoint returning exactly the caller profile. Creates only a missing profile through the guarded private helper; existing profile values and timestamps remain unchanged.';

notify pgrst, 'reload schema';



-- 20260930175442 add_admin_get_support_inbox_rpc

create function private.admin_get_support_inbox()
returns table (
  id uuid,
  user_id uuid,
  customer_name text,
  customer_email text,
  customer_phone text,
  subject text,
  status text,
  message text,
  admin_reply text,
  admin_note text,
  created_at timestamptz,
  updated_at timestamptz,
  conversation_id uuid,
  support_request_id uuid,
  conversation_count bigint,
  message_count bigint,
  conversations jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
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
      count(*) + count(*) filter (where btrim(r.admin_reply) <> '') as stored_message_count
    from request_context as r
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
$function$;

revoke execute on function private.admin_get_support_inbox()
from public, anon, authenticated, service_role;
grant execute on function private.admin_get_support_inbox() to authenticated;

comment on function private.admin_get_support_inbox() is
'Admin-only read projection: one inbox row per signed-in account UUID or separate guest email group, with nested normalized-subject conversations. Uses auth.users only to resolve the login email for support request owners. id/conversation_id identify the newest active subject root, compatible with admin_get_support_messages; support_request_id identifies that thread latest updated request. message_count counts customer requests plus current nonblank saved replies, not overwritten reply history or unread messages. Does not merge guest submissions into authenticated accounts.';

create function public.admin_get_support_inbox()
returns table (
  id uuid,
  user_id uuid,
  customer_name text,
  customer_email text,
  customer_phone text,
  subject text,
  status text,
  message text,
  admin_reply text,
  admin_note text,
  created_at timestamptz,
  updated_at timestamptz,
  conversation_id uuid,
  support_request_id uuid,
  conversation_count bigint,
  message_count bigint,
  conversations jsonb
)
language sql
stable
security invoker
set search_path = ''
as $function$
  select i.* from private.admin_get_support_inbox() as i;
$function$;

revoke execute on function public.admin_get_support_inbox()
from public, anon, authenticated, service_role;
grant execute on function public.admin_get_support_inbox() to authenticated;

comment on function public.admin_get_support_inbox() is
'No-argument admin inbox endpoint. Guarded private helper checks the existing admin allowlist. Returns account contact details and compact conversation summaries; callers use nested conversation_id with admin_get_support_messages and support_request_id with admin_update_support_request. Read-only, with no schema/data changes.';

notify pgrst, 'reload schema';



-- 20260930181531 support_admin_messages_conversation_argument_compatibility

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



-- 20260930203603 add_admin_send_support_message_with_reply_history

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



-- 20260930233458 add_start_customer_support_conversation_rpc

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



-- 20261002182005 create_instagram_reels_with_admin_rls
create table public.instagram_reels (
  id uuid primary key default gen_random_uuid(),
  media_id text unique,
  media_url text,
  instagram_url text,
  username text,
  profile_image text,
  thumbnail_url text,
  caption text not null default '',
  media_type text,
  published_at timestamptz,
  view_count bigint check (view_count is null or view_count >= 0),
  like_count bigint check (like_count is null or like_count >= 0),
  comment_count bigint check (comment_count is null or comment_count >= 0),
  category text,
  shop_url text,
  product_id uuid references public.products(id) on delete set null,
  is_active boolean not null default true,
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.instagram_reels enable row level security;

revoke all on table public.instagram_reels from public, anon, authenticated;
grant select on table public.instagram_reels to anon;
grant select, insert, update, delete on table public.instagram_reels to authenticated, service_role;

create policy instagram_reels_read
  on public.instagram_reels
  for select to anon, authenticated
  using (is_active);

create policy instagram_reels_admin
  on public.instagram_reels
  for all to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));

create trigger instagram_reels_updated
  before update on public.instagram_reels
  for each row execute function private.touch_updated_at();

create index instagram_reels_active_order_idx
  on public.instagram_reels (display_order, created_at desc, id)
  where is_active;

create index instagram_reels_published_idx
  on public.instagram_reels (published_at desc, id)
  where media_id is not null;

create index instagram_reels_product_idx
  on public.instagram_reels (product_id);

notify pgrst, 'reload schema';


-- 20261003140035 allow_svg_category_images_only

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $$
begin
  if not exists (
    select 1 from storage.buckets
    where id = 'category-images'
      and allowed_mime_types = array['image/jpeg','image/png','image/webp']::text[]
  ) then
    raise exception 'Category image bucket configuration changed since inspection; migration aborted';
  end if;
end $$;

update storage.buckets
set allowed_mime_types = array_append(allowed_mime_types, 'image/svg+xml')
where id = 'category-images';



-- 20261003154622 secure_permanent_product_delete
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



-- 20261003162752 add_delete_product_rpc_compatibility

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


