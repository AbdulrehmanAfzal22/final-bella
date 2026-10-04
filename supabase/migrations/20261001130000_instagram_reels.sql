create table public.instagram_reels (
  id uuid primary key default gen_random_uuid(),
  instagram_url text not null check (instagram_url ~* '^https?://(www\.)?instagram\.com/reel/[a-z0-9_-]+/?(\?.*)?$'),
  username text not null default 'bellabyrt' check (username ~ '^[A-Za-z0-9._]{1,30}$'),
  profile_image text check (profile_image is null or profile_image ~ '^https://'),
  thumbnail_url text check (thumbnail_url is null or thumbnail_url ~ '^https://'),
  category text not null default '' check (length(category) <= 120),
  shop_url text check (shop_url is null or shop_url ~ '^https://' or (left(shop_url, 1) = '/' and left(shop_url, 2) <> '//')),
  product_id uuid references public.products(id) on delete set null,
  is_active boolean not null default true,
  display_order integer not null default 0 check (display_order >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index instagram_reels_active_order_idx
  on public.instagram_reels(is_active, display_order, created_at);
create trigger instagram_reels_updated
  before update on public.instagram_reels
  for each row execute function private.touch_updated_at();

alter table public.instagram_reels enable row level security;
revoke all on public.instagram_reels from anon, authenticated;
grant select on public.instagram_reels to anon, authenticated;
grant insert, update, delete on public.instagram_reels to authenticated;
grant all on public.instagram_reels to service_role;

create policy instagram_reels_active_read
  on public.instagram_reels for select to anon, authenticated
  using (is_active or (select private.is_admin()));

create policy instagram_reels_admin_write
  on public.instagram_reels for all to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));