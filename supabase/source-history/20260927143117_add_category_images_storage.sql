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
