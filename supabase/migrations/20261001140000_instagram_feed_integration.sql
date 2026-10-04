alter table public.instagram_reels
  add column media_id text,
  add column media_url text,
  add column media_type text,
  add column caption text not null default '',
  add column published_at timestamptz,
  add column view_count bigint check (view_count is null or view_count >= 0),
  add column like_count bigint check (like_count is null or like_count >= 0),
  add column comment_count bigint check (comment_count is null or comment_count >= 0);

create unique index instagram_reels_media_id_unique_idx
  on public.instagram_reels(media_id);
drop index if exists public.instagram_reels_thumbnail_unique_idx;

create table public.instagram_feed_settings (
  id boolean primary key default true check (id),
  username text not null default 'bellabyrt' check (username ~ '^[A-Za-z0-9._]{1,30}$'),
  profile_url text not null default 'https://www.instagram.com/bellabyrt/' check (profile_url ~ '^https://www\.instagram\.com/'),
  reels_to_display integer not null default 10 check (reels_to_display between 1 and 50),
  is_enabled boolean not null default true,
  autoplay_enabled boolean not null default true,
  autoplay_interval_seconds integer not null default 3 check (autoplay_interval_seconds between 3 and 10),
  desktop_cards integer not null default 5 check (desktop_cards between 4 and 5),
  mobile_cards numeric(3,2) not null default 1.20 check (mobile_cards between 1 and 2),
  last_synced_at timestamptz,
  updated_at timestamptz not null default now()
);

insert into public.instagram_feed_settings(id) values(true) on conflict(id) do nothing;
create trigger instagram_feed_settings_updated
  before update on public.instagram_feed_settings
  for each row execute function private.touch_updated_at();

alter table public.instagram_feed_settings enable row level security;
revoke all on public.instagram_feed_settings from anon, authenticated;
grant select on public.instagram_feed_settings to anon, authenticated;
grant update on public.instagram_feed_settings to authenticated;
grant all on public.instagram_feed_settings to service_role;
create policy instagram_feed_settings_read on public.instagram_feed_settings
  for select to anon, authenticated using (is_enabled or (select private.is_admin()));
create policy instagram_feed_settings_admin_update on public.instagram_feed_settings
  for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));

create table public.instagram_private_connection (
  id boolean primary key default true check (id),
  instagram_user_id text not null,
  username text not null,
  access_token text not null,
  token_expires_at timestamptz not null,
  profile_image_url text,
  connected_at timestamptz not null default now(),
  last_synced_at timestamptz
);
create table public.instagram_oauth_states (
  state text primary key,
  admin_user_id uuid not null references auth.users(id) on delete cascade,
  redirect_origin text not null,
  expires_at timestamptz not null
);
alter table public.instagram_private_connection enable row level security;
alter table public.instagram_oauth_states enable row level security;
revoke all on public.instagram_private_connection, public.instagram_oauth_states from public, anon, authenticated;
grant all on public.instagram_private_connection, public.instagram_oauth_states to service_role;