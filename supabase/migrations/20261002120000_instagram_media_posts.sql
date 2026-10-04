alter table public.instagram_reels
  drop constraint if exists instagram_reels_instagram_url_check;

alter table public.instagram_reels
  add constraint instagram_reels_instagram_url_check
  check (instagram_url ~* '^https?://(www\.)?instagram\.com/(reel|p|tv)/[a-z0-9_-]+/?(\?.*)?$');