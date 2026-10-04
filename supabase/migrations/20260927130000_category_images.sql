ALTER TABLE public.categories
  ADD COLUMN image_path text,
  ADD COLUMN image_alt text NOT NULL DEFAULT '',
  ADD COLUMN display_order integer NOT NULL DEFAULT 0
    CHECK (display_order >= 0);

CREATE INDEX categories_display_order_idx
  ON public.categories(display_order, name);

INSERT INTO storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'category-images',
  'category-images',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY category_images_admin_insert
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'category-images'
    AND (SELECT private.is_admin())
  );

CREATE POLICY category_images_admin_read
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'category-images'
    AND (SELECT private.is_admin())
  );

CREATE POLICY category_images_admin_delete
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'category-images'
    AND (SELECT private.is_admin())
  );

CREATE POLICY category_images_admin_update
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'category-images'
    AND (SELECT private.is_admin())
  )
  WITH CHECK (
    bucket_id = 'category-images'
    AND (SELECT private.is_admin())
  );