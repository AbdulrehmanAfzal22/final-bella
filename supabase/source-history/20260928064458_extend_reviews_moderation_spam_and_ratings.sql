
-- Maison Elan: review-only extension. Preserve legacy approved callers.
alter table public.reviews
  add column customer_name text not null default 'Customer',
  add column status text not null default 'pending',
  add column is_spam boolean not null default false,
  add column updated_at timestamptz not null default now();

update public.reviews r
set customer_name = coalesce(
      (select nullif(btrim(p.full_name), '') from public.profiles p where p.id = r.user_id),
      'Customer'),
    status = case when r.approved then 'approved' else 'pending' end,
    updated_at = r.created_at;

alter table public.reviews
  alter column user_id set default auth.uid(),
  add constraint reviews_status_check
    check (status in ('pending','approved','rejected','spam')),
  add constraint reviews_moderation_consistency_check
    check (approved = (status = 'approved') and is_spam = (status = 'spam')),
  drop constraint reviews_product_id_user_id_key;

-- Composite index covers product_id lookups and duplicate detection.
create index reviews_product_user_idx on public.reviews (product_id, user_id);
create index reviews_user_id_idx on public.reviews (user_id);
create index reviews_status_idx on public.reviews (status);
create index reviews_is_spam_idx on public.reviews (is_spam);

create function private.guard_review_submission()
returns trigger
language plpgsql volatile security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_duplicate boolean;
begin
  if v_user_id is null or new.user_id is distinct from v_user_id then
    raise exception 'Sign in and submit reviews only for your own account.' using errcode = '42501';
  end if;
  if new.status is distinct from 'pending' or new.approved is distinct from false
     or new.is_spam is distinct from false then
    raise exception 'Review moderation is controlled by an administrator.' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.products p
    where p.id = new.product_id and (p.status = 'published' or private.is_admin())
  ) then
    raise exception 'Product is not available for review.' using errcode = '22023';
  end if;
  -- The API uses READ COMMITTED. Reject stale-snapshot submission transactions.
  if current_setting('transaction_isolation') not in ('read committed','read uncommitted') then
    raise exception 'Submit reviews in a READ COMMITTED transaction.' using errcode = '40001';
  end if;
  -- Serialize only this customer's submissions for this product.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('maison-elan:review:' || new.product_id::text || ':' || v_user_id::text, 0)
  );
  select exists (
    select 1 from public.reviews r
    where r.product_id = new.product_id and r.user_id = v_user_id
  ) into v_duplicate;

  new.customer_name := coalesce(
    (select nullif(btrim(p.full_name), '') from public.profiles p where p.id = v_user_id),
    'Customer');
  new.is_spam := v_duplicate;
  new.status := case when v_duplicate then 'spam' else 'pending' end;
  new.approved := false;
  new.created_at := clock_timestamp();
  new.updated_at := new.created_at;
  return new;
end
$function$;

create function private.guard_review_moderation()
returns trigger
language plpgsql volatile security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null or not private.is_admin() then
    raise exception 'Only administrators can moderate reviews.' using errcode = '42501';
  end if;
  if new.id is distinct from old.id
     or new.product_id is distinct from old.product_id
     or new.user_id is distinct from old.user_id
     or new.customer_name is distinct from old.customer_name
     or new.rating is distinct from old.rating
     or new.comment is distinct from old.comment
     or new.created_at is distinct from old.created_at then
    raise exception 'Review content and ownership cannot be changed during moderation.' using errcode = '42501';
  end if;

  if new.status is distinct from old.status then
    -- Explicit status is authoritative.
    null;
  elsif new.approved is distinct from old.approved then
    -- Compatibility with the existing admin approve/hide toggle.
    new.status := case when new.approved then 'approved' else 'rejected' end;
  end if;
  new.approved := (new.status = 'approved');
  new.is_spam := (new.status = 'spam');
  new.updated_at := clock_timestamp();
  return new;
end
$function$;

revoke all on function private.guard_review_submission() from public, anon, authenticated, service_role;
revoke all on function private.guard_review_moderation() from public, anon, authenticated, service_role;

create trigger reviews_before_insert
before insert on public.reviews
for each row execute function private.guard_review_submission();

create trigger reviews_before_update
before update on public.reviews
for each row execute function private.guard_review_moderation();

alter table public.reviews enable row level security;
drop policy reviews_read on public.reviews;
drop policy reviews_insert_own on public.reviews;
drop policy reviews_admin_update on public.reviews;
drop policy reviews_admin_delete on public.reviews;

create policy reviews_read on public.reviews
for select to anon, authenticated
using (status = 'approved' or (select private.is_admin()));

create policy reviews_insert_own on public.reviews
for insert to authenticated
with check (
  user_id = (select auth.uid())
  and status in ('pending','spam')
  and approved = false
  and is_spam = (status = 'spam')
);

create policy reviews_admin_update on public.reviews
for update to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy reviews_admin_delete_spam on public.reviews
for delete to authenticated
using (status = 'spam' and is_spam and (select private.is_admin()));

revoke all on table public.reviews from public, anon, authenticated;
grant select on table public.reviews to anon, authenticated;
grant insert (product_id, user_id, rating, comment, approved)
  on public.reviews to authenticated;
grant update (status, approved) on public.reviews to authenticated;
grant delete on table public.reviews to authenticated;

-- A receipt for this submission, without giving customers SELECT access to pending reviews.
create function private.submit_review(p_product_id uuid, p_rating integer, p_comment text default '')
returns table (review_id uuid, status text, is_spam boolean)
language plpgsql volatile security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null then
    raise exception 'Sign in to submit a review.' using errcode = '42501';
  end if;
  return query
    insert into public.reviews as r (product_id, user_id, rating, comment)
    values (p_product_id, auth.uid(), p_rating, btrim(coalesce(p_comment, '')))
    returning r.id, r.status, r.is_spam;
end
$function$;

create function public.submit_review(p_product_id uuid, p_rating integer, p_comment text default '')
returns table (review_id uuid, status text, is_spam boolean)
language sql volatile security invoker
set search_path = ''
as $function$
  select * from private.submit_review(p_product_id, p_rating, p_comment);
$function$;

revoke all on function private.submit_review(uuid, integer, text) from public, anon, authenticated, service_role;
revoke all on function public.submit_review(uuid, integer, text) from public, anon, authenticated, service_role;
grant execute on function private.submit_review(uuid, integer, text) to authenticated;
grant execute on function public.submit_review(uuid, integer, text) to authenticated;

create view public.product_review_stats
with (security_invoker = true, security_barrier = true)
as
select p.id as product_id,
       avg(r.rating) as average_rating,
       count(r.id) as review_count
from public.products p
left join public.reviews r
  on r.product_id = p.id and r.status = 'approved'
group by p.id;

revoke all on table public.product_review_stats from public, anon, authenticated;
grant select on table public.product_review_stats to anon, authenticated, service_role;

comment on column public.reviews.customer_name is 'Public display name captured from the customer profile at submission; no email is exposed.';
comment on column public.reviews.approved is 'Legacy compatibility flag, synchronized with status by review triggers.';
comment on column public.reviews.is_spam is 'True while status is spam. Admin approval or rejection reclassifies the review.';
comment on view public.product_review_stats is 'Live approved-only averages and counts. Unrated visible products have NULL average_rating and zero review_count. Uses caller RLS.';
comment on function public.submit_review(uuid, integer, text) is 'Authenticated review submission; returns only the receipt for the new review. Duplicate submissions are retained with spam status.';

notify pgrst, 'reload schema';

