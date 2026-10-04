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
