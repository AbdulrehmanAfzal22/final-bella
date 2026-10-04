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
