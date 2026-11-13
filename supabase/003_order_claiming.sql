
begin;

alter table public.zerah_orders
  add column if not exists claimed_by uuid references auth.users(id),
  add column if not exists claimed_at timestamptz;

create or replace function private.zerah_claim_store_order_impl(
  p_order_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store_id uuid;
  v_status text;
  v_claimed_by uuid;
begin
  select store_id, status, claimed_by
    into v_store_id, v_status, v_claimed_by
  from public.zerah_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'Order not found.';
  end if;

  if not private.zerah_has_store_role(
    v_store_id, array['owner', 'manager', 'cashier']
  ) then
    raise exception 'You are not assigned to this store.';
  end if;

  if v_status <> 'pending' then
    raise exception 'This order is no longer waiting.';
  end if;

  if v_claimed_by is not null and v_claimed_by <> (select auth.uid()) then
    raise exception 'Another cashier has already accepted this order.';
  end if;

  update public.zerah_orders
  set claimed_by = (select auth.uid()),
      claimed_at = now()
  where id = p_order_id;
end;
$$;

create or replace function public.zerah_claim_store_order(
  p_order_id uuid
)
returns void
language sql
security invoker
set search_path = ''
as $$
  select private.zerah_claim_store_order_impl(p_order_id);
$$;

revoke all on function private.zerah_claim_store_order_impl(uuid) from public;
grant execute on function private.zerah_claim_store_order_impl(uuid)
  to authenticated;

revoke all on function public.zerah_claim_store_order(uuid) from public;
grant execute on function public.zerah_claim_store_order(uuid)
  to authenticated;

create or replace function private.zerah_check_order_claim()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status = 'pending' and new.status = 'confirmed'
     and old.claimed_by is distinct from (select auth.uid())
     and not private.zerah_has_store_role(
       old.store_id, array['owner', 'manager']
     ) then
    raise exception 'Accept this order before confirming it.';
  end if;

  return new;
end;
$$;

drop trigger if exists zerah_check_order_claim
  on public.zerah_orders;

create trigger zerah_check_order_claim
before update of status on public.zerah_orders
for each row
execute function private.zerah_check_order_claim();

commit;