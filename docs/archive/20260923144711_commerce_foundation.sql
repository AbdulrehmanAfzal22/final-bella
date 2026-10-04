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
