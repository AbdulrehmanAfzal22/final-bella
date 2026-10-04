create or replace function public.save_product(payload jsonb)
returns uuid
language plpgsql
set search_path to ''
as $function$
declare pid uuid=(payload->>'id')::uuid; item jsonb; vid uuid; ids uuid[]='{}';
begin
 if not private.is_admin() then raise exception 'Admin access required' using errcode='42501';end if;
 if jsonb_array_length(payload->'variants')<1 then raise exception 'Add at least one variant';end if;
 if payload->>'status'='published' and jsonb_array_length(payload->'images')<1 then raise exception 'Upload at least one image before publishing';end if;
 insert into public.products(id,name,description,care,price_cents,category_id,status,featured,department)
 values(pid,trim(payload->>'name'),coalesce(payload->>'description',''),coalesce(payload->>'care',''),(payload->>'price_cents')::int,nullif(payload->>'category_id','')::uuid,payload->>'status',coalesce((payload->>'featured')::boolean,false),coalesce(nullif(payload->>'department',''),'unisex'))
 on conflict(id) do update set name=excluded.name,description=excluded.description,care=excluded.care,price_cents=excluded.price_cents,category_id=excluded.category_id,status=excluded.status,featured=excluded.featured,department=excluded.department;
 for item in select * from jsonb_array_elements(payload->'variants') loop
  vid=coalesce(nullif(item->>'id','')::uuid,gen_random_uuid());
  if exists(select 1 from public.product_variants where id=vid and product_id<>pid) then raise exception 'Variant belongs to another product';end if;
  insert into public.product_variants(id,product_id,color,color_hex,size,stock,active)
  values(vid,pid,trim(item->>'color'),item->>'color_hex',trim(item->>'size'),(item->>'stock')::int,true)
  on conflict(id) do update set color=excluded.color,color_hex=excluded.color_hex,size=excluded.size,stock=excluded.stock,active=true;
  ids=array_append(ids,vid);
 end loop;
 update public.product_variants set active=false where product_id=pid and not(id=any(ids));
 delete from public.product_images where product_id=pid;
 for item in select * from jsonb_array_elements(payload->'images') loop
  if (item->>'path') not like pid::text||'/%' or not exists(select 1 from storage.objects where bucket_id='product-images' and name=item->>'path') then raise exception 'Product image not uploaded';end if;
  insert into public.product_images(product_id,path,color,alt,position) values(pid,item->>'path',nullif(item->>'color',''),coalesce(item->>'alt',payload->>'name'),coalesce((item->>'position')::int,0));
 end loop;
 return pid;
end$function$;
