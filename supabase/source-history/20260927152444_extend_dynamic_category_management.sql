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
