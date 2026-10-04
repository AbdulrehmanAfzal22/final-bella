alter table public.products
  add column department text not null default 'unisex'
  check (department in ('men','women','kids','unisex'));

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  order_id uuid references public.orders(id),
  subject text not null check (length(trim(subject)) between 1 and 200),
  status text not null default 'open' check (status in ('open','in_progress','resolved','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.support_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  sender_role text not null check (sender_role in ('customer','admin')),
  sender_id uuid references auth.users(id),
  body text not null check (length(trim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);

alter table public.support_tickets enable row level security;
alter table public.support_messages enable row level security;

create policy tickets_read on public.support_tickets
for select to authenticated
using (user_id = auth.uid() or private.is_admin());

create policy tickets_admin_update on public.support_tickets
for update to authenticated
using (private.is_admin())
with check (private.is_admin());

create policy messages_read on public.support_messages
for select to authenticated
using (
  exists (select 1 from public.support_tickets t
    where t.id = support_messages.ticket_id
      and (t.user_id = auth.uid() or private.is_admin()))
);

create trigger tickets_updated before update on public.support_tickets
for each row execute function private.touch_updated_at();

create or replace function public.create_support_ticket(p_subject text, p_body text, p_order_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path to ''
as $$
declare uid uuid := auth.uid(); v_ticket_id uuid;
begin
  if uid is null then raise exception 'Authentication required' using errcode = '28000'; end if;
  if p_order_id is not null and not exists (select 1 from public.orders where id = p_order_id and user_id = uid) then
    raise exception 'Order not found';
  end if;
  insert into public.support_tickets (user_id, order_id, subject)
  values (uid, p_order_id, p_subject)
  returning id into v_ticket_id;
  insert into public.support_messages (ticket_id, sender_role, sender_id, body)
  values (v_ticket_id, 'customer', uid, p_body);
  return v_ticket_id;
end;
$$;

create or replace function public.add_support_message(p_ticket_id uuid, p_body text)
returns void
language plpgsql
security definer
set search_path to ''
as $$
declare uid uuid := auth.uid(); is_owner boolean; is_adm boolean := private.is_admin();
begin
  if uid is null then raise exception 'Authentication required' using errcode = '28000'; end if;
  select exists(select 1 from public.support_tickets where id = p_ticket_id and user_id = uid) into is_owner;
  if not is_owner and not is_adm then raise exception 'Ticket not found'; end if;
  insert into public.support_messages (ticket_id, sender_role, sender_id, body)
  values (p_ticket_id, case when is_adm then 'admin' else 'customer' end, uid, p_body);
  if is_adm then
    update public.support_tickets set status = 'in_progress' where id = p_ticket_id and status = 'open';
  else
    update public.support_tickets set status = 'open' where id = p_ticket_id and status = 'resolved';
  end if;
end;
$$;

create or replace function public.set_ticket_status(p_ticket_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path to ''
as $$
begin
  if not private.is_admin() then raise exception 'Admin access required' using errcode = '42501'; end if;
  if p_status not in ('open','in_progress','resolved','closed') then raise exception 'Invalid status'; end if;
  update public.support_tickets set status = p_status where id = p_ticket_id;
  if not found then raise exception 'Ticket not found'; end if;
end;
$$;
