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
