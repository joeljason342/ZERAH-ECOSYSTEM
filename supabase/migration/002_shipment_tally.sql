create table public.zerah_shipments (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.zerah_stores(id),
  sender_name text not null,
  status text not null default 'prepared'
    check (status in (
      'prepared',
      'dispatched',
      'partially_received',
      'received',
      'short_received',
      'cancelled'
    )),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  dispatched_by uuid references auth.users(id),
  dispatched_at timestamptz,
  received_at timestamptz,
  unique (id, store_id)
);

create table public.zerah_shipment_items (
  shipment_id uuid not null,
  store_id uuid not null references public.zerah_stores(id),
  product_id bigint not null references public.zerah_products(id),
  quantity_sent integer not null check (quantity_sent > 0),
  quantity_received integer not null default 0
    check (quantity_received >= 0 and quantity_received <= quantity_sent),
  primary key (shipment_id, product_id),
  unique (shipment_id, store_id, product_id),
  foreign key (shipment_id, store_id)
    references public.zerah_shipments(id, store_id)
);

create table public.zerah_receipt_events (
  id bigint generated always as identity primary key,
  shipment_id uuid not null,
  store_id uuid not null,
  product_id bigint not null,
  quantity_received integer not null check (quantity_received > 0),
  received_by uuid references auth.users(id),
  received_at timestamptz not null default now(),
  foreign key (shipment_id, store_id, product_id)
    references public.zerah_shipment_items(shipment_id, store_id, product_id)
);

create index zerah_shipments_store_status_idx
  on public.zerah_shipments(store_id, status, created_at);

alter table public.zerah_shipments enable row level security;
alter table public.zerah_shipment_items enable row level security;
alter table public.zerah_receipt_events enable row level security;

create policy "Store team reads shipments"
on public.zerah_shipments for select
to authenticated
using (
  private.zerah_has_store_role(
    store_id, array['owner', 'manager', 'cashier']
  )
);

create policy "Store team reads shipment items"
on public.zerah_shipment_items for select
to authenticated
using (
  private.zerah_has_store_role(
    store_id, array['owner', 'manager', 'cashier']
  )
);

create policy "Store team reads receipt events"
on public.zerah_receipt_events for select
to authenticated
using (
  private.zerah_has_store_role(
    store_id, array['owner', 'manager', 'cashier']
  )
);

grant select on public.zerah_shipments,
  public.zerah_shipment_items,
  public.zerah_receipt_events
to authenticated;

create or replace function private.zerah_create_shipment_impl(
  p_store_id uuid,
  p_sender_name text,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_shipment_id uuid;
  v_item_count integer;
  v_inserted_count integer;
begin
  if not private.zerah_has_store_role(
    p_store_id, array['owner', 'manager']
  ) then
    raise exception 'Only a store owner or manager can create a shipment.';
  end if;

  if p_sender_name is null or length(trim(p_sender_name)) = 0 then
    raise exception 'Enter the supplier or warehouse name.';
  end if;

  if p_items is null
     or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0
     or jsonb_array_length(p_items) > 100 then
    raise exception 'Add between 1 and 100 shipment items.';
  end if;

  select count(*) into v_item_count
  from jsonb_to_recordset(p_items) as x(product_id bigint, quantity_sent integer)
  where x.product_id is not null and x.quantity_sent > 0;

  if v_item_count <> jsonb_array_length(p_items) then
    raise exception 'Each item needs a product and a positive whole-number quantity.';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_items) as x(product_id bigint, quantity_sent integer)
    group by x.product_id
    having count(*) > 1
  ) then
    raise exception 'A product can appear only once in a shipment.';
  end if;

  insert into public.zerah_shipments(
    store_id, sender_name, created_by
  )
  values (
    p_store_id, trim(p_sender_name), (select auth.uid())
  )
  returning id into v_shipment_id;

  insert into public.zerah_shipment_items(
    shipment_id, store_id, product_id, quantity_sent
  )
  select
    v_shipment_id,
    p_store_id,
    p.id,
    x.quantity_sent
  from jsonb_to_recordset(p_items) as x(product_id bigint, quantity_sent integer)
  join public.zerah_products p
    on p.id = x.product_id and p.is_active;

  get diagnostics v_inserted_count = row_count;

  if v_inserted_count <> v_item_count then
    raise exception 'One or more products are unavailable.';
  end if;

  return v_shipment_id;
end;
$$;

create or replace function public.zerah_create_shipment(
  p_store_id uuid,
  p_sender_name text,
  p_items jsonb
)
returns uuid
language sql
security invoker
set search_path = ''
as $$
  select private.zerah_create_shipment_impl(
    p_store_id, p_sender_name, p_items
  );
$$;

create or replace function private.zerah_dispatch_shipment_impl(
  p_shipment_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store_id uuid;
  v_status text;
begin
  select s.store_id, s.status
    into v_store_id, v_status
  from public.zerah_shipments s
  where s.id = p_shipment_id
  for update;

  if not found then
    raise exception 'Shipment not found.';
  end if;

  if not private.zerah_has_store_role(
    v_store_id, array['owner', 'manager']
  ) then
    raise exception 'Only a store owner or manager can dispatch a shipment.';
  end if;

  if v_status <> 'prepared' then
    raise exception 'Only a prepared shipment can be dispatched.';
  end if;

  update public.zerah_shipments
  set status = 'dispatched',
      dispatched_by = (select auth.uid()),
      dispatched_at = now()
  where id = p_shipment_id;
end;
$$;

create or replace function public.zerah_dispatch_shipment(
  p_shipment_id uuid
)
returns void
language sql
security invoker
set search_path = ''
as $$
  select private.zerah_dispatch_shipment_impl(p_shipment_id);
$$;

create or replace function private.zerah_receive_shipment_impl(
  p_shipment_id uuid,
  p_items jsonb,
  p_final boolean
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store_id uuid;
  v_status text;
  v_item record;
  v_quantity_sent integer;
  v_quantity_received integer;
  v_all_received boolean;
  v_new_status text;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Shipment receipt items must be a list.';
  end if;

  if not p_final and jsonb_array_length(p_items) = 0 then
    raise exception 'Enter at least one received quantity.';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_items) as x(product_id bigint, quantity_received integer)
    where x.product_id is null
       or x.quantity_received is null
       or x.quantity_received < 0
  ) then
    raise exception 'Received quantities must be zero or a positive whole number.';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_items) as x(product_id bigint, quantity_received integer)
    group by x.product_id
    having count(*) > 1
  ) then
    raise exception 'A product can appear only once in a receipt.';
  end if;

  select s.store_id, s.status
    into v_store_id, v_status
  from public.zerah_shipments s
  where s.id = p_shipment_id
  for update;

  if not found then
    raise exception 'Shipment not found.';
  end if;

  if not private.zerah_has_store_role(
    v_store_id, array['owner', 'manager', 'cashier']
  ) then
    raise exception 'You are not assigned to receive goods for this store.';
  end if;

  if v_status not in ('dispatched', 'partially_received') then
    raise exception 'Only dispatched shipments can be received.';
  end if;

  for v_item in
    select x.product_id, x.quantity_received
    from jsonb_to_recordset(p_items) as x(product_id bigint, quantity_received integer)
    order by x.product_id
  loop
    select i.quantity_sent, i.quantity_received
      into v_quantity_sent, v_quantity_received
    from public.zerah_shipment_items i
    where i.shipment_id = p_shipment_id
      and i.product_id = v_item.product_id
    for update;

    if not found then
      raise exception 'A product in this receipt was not in the shipment.';
    end if;

    if v_item.quantity_received > v_quantity_sent - v_quantity_received then
      raise exception 'Received quantity is greater than the remaining quantity sent.';
    end if;

    if v_item.quantity_received > 0 then
      update public.zerah_shipment_items
      set quantity_received = quantity_received + v_item.quantity_received
      where shipment_id = p_shipment_id
        and product_id = v_item.product_id;

      insert into public.zerah_receipt_events(
        shipment_id, store_id, product_id, quantity_received, received_by
      )
      values (
        p_shipment_id, v_store_id, v_item.product_id,
        v_item.quantity_received, (select auth.uid())
      );

      insert into public.zerah_inventory(
        store_id, product_id, quantity_on_hand, updated_at
      )
      values (
        v_store_id, v_item.product_id, v_item.quantity_received, now()
      )
      on conflict (store_id, product_id)
      do update set
        quantity_on_hand = public.zerah_inventory.quantity_on_hand
          + excluded.quantity_on_hand,
        updated_at = now();

      insert into public.zerah_stock_movements(
        store_id, product_id, quantity_change, reason, created_by
      )
      values (
        v_store_id, v_item.product_id, v_item.quantity_received,
        'shipment_receipt', (select auth.uid())
      );
    end if;
  end loop;

  select bool_and(i.quantity_received = i.quantity_sent)
    into v_all_received
  from public.zerah_shipment_items i
  where i.shipment_id = p_shipment_id;

  if v_all_received then
    v_new_status := 'received';
  elsif p_final then
    v_new_status := 'short_received';
  else
    v_new_status := 'partially_received';
  end if;

  update public.zerah_shipments
  set status = v_new_status,
      received_at = case
        when v_new_status in ('received', 'short_received') then now()
        else received_at
      end
  where id = p_shipment_id;

  return v_new_status;
end;
$$;

create or replace function public.zerah_receive_shipment(
  p_shipment_id uuid,
  p_items jsonb,
  p_final boolean
)
returns text
language sql
security invoker
set search_path = ''
as $$
  select private.zerah_receive_shipment_impl(
    p_shipment_id, p_items, p_final
  );
$$;

revoke all on function private.zerah_create_shipment_impl(uuid, text, jsonb)
  from public;
revoke all on function private.zerah_dispatch_shipment_impl(uuid)
  from public;
revoke all on function private.zerah_receive_shipment_impl(uuid, jsonb, boolean)
  from public;

grant execute on function private.zerah_create_shipment_impl(uuid, text, jsonb)
  to authenticated;
grant execute on function private.zerah_dispatch_shipment_impl(uuid)
  to authenticated;
grant execute on function private.zerah_receive_shipment_impl(uuid, jsonb, boolean)
  to authenticated;

revoke all on function public.zerah_create_shipment(uuid, text, jsonb)
  from public;
revoke all on function public.zerah_dispatch_shipment(uuid)
  from public;
revoke all on function public.zerah_receive_shipment(uuid, jsonb, boolean)
  from public;

grant execute on function public.zerah_create_shipment(uuid, text, jsonb)
  to authenticated;
grant execute on function public.zerah_dispatch_shipment(uuid)
  to authenticated;
grant execute on function public.zerah_receive_shipment(uuid, jsonb, boolean)
  to authenticated;