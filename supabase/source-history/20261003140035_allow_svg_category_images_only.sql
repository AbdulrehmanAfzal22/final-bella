
set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $$
begin
  if not exists (
    select 1 from storage.buckets
    where id = 'category-images'
      and allowed_mime_types = array['image/jpeg','image/png','image/webp']::text[]
  ) then
    raise exception 'Category image bucket configuration changed since inspection; migration aborted';
  end if;
end $$;

update storage.buckets
set allowed_mime_types = array_append(allowed_mime_types, 'image/svg+xml')
where id = 'category-images';

