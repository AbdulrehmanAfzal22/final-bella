DO $backfill_uncategorized$
DECLARE
  uncategorized_id uuid;
  suffix text;
BEGIN
  IF EXISTS(SELECT 1 FROM public.products WHERE category_id IS NULL) THEN
    INSERT INTO public.categories(name,slug)
    VALUES('Uncategorized','uncategorized')
    ON CONFLICT DO NOTHING;
    SELECT id INTO uncategorized_id FROM public.categories WHERE slug='uncategorized';
    IF uncategorized_id IS NULL THEN
      suffix := replace(gen_random_uuid()::text,'-','');
      INSERT INTO public.categories(name,slug)
      VALUES('Uncategorized '||suffix,'uncategorized-'||suffix)
      RETURNING id INTO uncategorized_id;
    END IF;
    UPDATE public.products SET category_id=uncategorized_id WHERE category_id IS NULL;
  END IF;
END
$backfill_uncategorized$;

ALTER TABLE public.products ALTER COLUMN category_id SET NOT NULL;

CREATE OR REPLACE FUNCTION public.save_product(payload jsonb)
RETURNS uuid
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  pid uuid := (payload->>'id')::uuid;
  item jsonb;
  vid uuid;
  ids uuid[] := '{}';
  category_id uuid := nullif(btrim(payload->>'category_id'),'')::uuid;
  product_status text := payload->>'status';
BEGIN
  IF NOT private.is_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';
  END IF;

  IF category_id IS NULL THEN
    RAISE EXCEPTION 'Choose a category before saving this product' USING ERRCODE='22023';
  END IF;
  IF jsonb_typeof(payload->'variants') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Product variants must be provided as a list' USING ERRCODE='22023';
  END IF;
  IF jsonb_array_length(payload->'variants') < 1 THEN
    RAISE EXCEPTION 'Add at least one variant' USING ERRCODE='22023';
  END IF;
  IF jsonb_typeof(payload->'images') IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Product images must be provided as a list' USING ERRCODE='22023';
  END IF;
  IF product_status='published' THEN
    IF length(btrim(coalesce(payload->>'description','')))=0 THEN
      RAISE EXCEPTION 'Add a product description before publishing' USING ERRCODE='22023';
    END IF;
    IF jsonb_array_length(payload->'images') < 1 THEN
      RAISE EXCEPTION 'Upload at least one image before publishing' USING ERRCODE='22023';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(payload->'variants') v
      WHERE length(btrim(v->>'color'))>0 AND length(btrim(v->>'size'))>0
    ) THEN
      RAISE EXCEPTION 'Add at least one complete colour and size variant before publishing' USING ERRCODE='22023';
    END IF;
  END IF;

  INSERT INTO public.products(id,name,description,care,price_cents,category_id,status,featured,department)
  VALUES(pid,trim(payload->>'name'),coalesce(payload->>'description',''),coalesce(payload->>'care',''),(payload->>'price_cents')::int,category_id,product_status,coalesce((payload->>'featured')::boolean,false),coalesce(nullif(payload->>'department',''),'unisex'))
  ON CONFLICT(id) DO UPDATE SET name=excluded.name,description=excluded.description,care=excluded.care,price_cents=excluded.price_cents,category_id=excluded.category_id,status=excluded.status,featured=excluded.featured,department=excluded.department;

  FOR item IN SELECT * FROM jsonb_array_elements(payload->'variants') LOOP
    vid := coalesce(nullif(item->>'id','')::uuid,gen_random_uuid());
    IF EXISTS(SELECT 1 FROM public.product_variants WHERE id=vid AND product_id<>pid) THEN
      RAISE EXCEPTION 'Variant belongs to another product';
    END IF;
    INSERT INTO public.product_variants(id,product_id,color,color_hex,size,stock,active)
    VALUES(vid,pid,trim(item->>'color'),item->>'color_hex',trim(item->>'size'),(item->>'stock')::int,true)
    ON CONFLICT(id) DO UPDATE SET color=excluded.color,color_hex=excluded.color_hex,size=excluded.size,stock=excluded.stock,active=true;
    ids := array_append(ids,vid);
  END LOOP;

  UPDATE public.product_variants SET active=false WHERE product_id=pid AND NOT(id=ANY(ids));
  DELETE FROM public.product_images WHERE product_id=pid;
  FOR item IN SELECT * FROM jsonb_array_elements(payload->'images') LOOP
    IF (item->>'path') NOT LIKE pid::text||'/%' OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='product-images' AND name=item->>'path') THEN
      RAISE EXCEPTION 'Product image not uploaded';
    END IF;
    INSERT INTO public.product_images(product_id,path,color,alt,position)
    VALUES(pid,item->>'path',nullif(item->>'color',''),coalesce(item->>'alt',payload->>'name'),coalesce((item->>'position')::int,0));
  END LOOP;
  RETURN pid;
END
$function$;

REVOKE ALL ON FUNCTION public.save_product(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.save_product(jsonb) TO authenticated;
NOTIFY pgrst,'reload schema';