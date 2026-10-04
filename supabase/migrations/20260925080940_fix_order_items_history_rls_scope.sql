drop policy if exists order_items_read on public.order_items;
create policy order_items_read on public.order_items
for select to authenticated
using (
  exists (
    select 1 from public.orders o
    where o.id = order_items.order_id
      and (o.user_id = auth.uid() or private.is_admin())
  )
);

drop policy if exists history_read on public.order_status_history;
create policy history_read on public.order_status_history
for select to authenticated
using (
  exists (
    select 1 from public.orders o
    where o.id = order_status_history.order_id
      and (o.user_id = auth.uid() or private.is_admin())
  )
);
