
create schema if not exists private;

create table public.zerah_stores (
  id uuid primary key,
  name text not null,
  is_active boolean not null default true
);

create table public.zerah_products (
  id bigint primary key,
  sku text not null unique,
  barcode text,
  name text not null,
  category text not null default 'General',
  purchase_cost numeric(12,2),
  selling_price numeric(12,2) not null check (selling_price >= 0),
  minimum_stock integer not null default 0 check (minimum_stock >= 0),
  is_active boolean not null default true
);

create table public.zerah_inventory (
  store_id uuid not null references public.zerah_stores(id),
  product_id bigint not null references public.zerah_products(id),
  quantity_on_hand integer not null default 0 check (quantity_on_hand >= 0),
  primary key (store_id, product_id)
);

create table public.zerah_store_memberships (
  store_id uuid not null references public.zerah_stores(id),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'manager', 'cashier')),
  primary key (store_id, user_id)
);

create table public.zerah_orders (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.zerah_stores(id),
  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'cancelled')),
  total_amount numeric(12,2) not null default 0,
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users(id),
  unique (id, store_id)
);

create table public.zerah_order_items (
  order_id uuid not null,
  store_id uuid not null,
  product_id bigint not null references public.zerah_products(id),
  quantity integer not null check (quantity > 0),
  unit_price numeric(12,2) not null,
  unit_cost numeric(12,2),
  line_total numeric(12,2) generated always as (unit_price * quantity) stored,
  primary key (order_id, product_id),
  foreign key (order_id, store_id)
    references public.zerah_orders(id, store_id) on delete cascade,
  foreign key (store_id, product_id)
    references public.zer

    create schema if not exists private;

create table public.zerah_stores (
  id uuid primary key,
  name text not null,
  is_active boolean not null default true
);

create table public.zerah_products (
  id bigint primary key,
  sku text not null unique,
  barcode text,
  name text not null,
  category text,
  purchase_cost numeric(12,2),
  selling_price numeric(12,2) not null check (selling_price >= 0),
  minimum_stock integer not null default 0 check (minimum_stock >= 0),
  is_active boolean not null default true
);

create table public.zerah_inventory (
  store_id uuid not null references public.zerah_stores(id),
  product_id bigint not null references public.zerah_products(id),
  quantity_on_hand integer not null default 0 check (quantity_on_hand >= 0),
  primary key (store_id, product_id)
);

create table public.zerah_store_memberships (
  store_id uuid not null references public.zerah_stores(id),
  user_id uuid not null references auth.users(id),
  role text not null check (role in ('owner', 'manager', 'cashier')),
  primary key (store_id, user_id)
);

create table public.zerah_orders (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.zerah_stores(id),
  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'cancelled')),
  total_amount numeric(12,2) not null default 0,
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users(id),
  unique (id, store_id)
);

create table public.zerah_order_items (
  order_id uuid not null,
  store_id uuid not null,
  product_id bigint not null,
  quantity integer not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  unit_cost numeric(12,2),
  line_total numeric(12,2) generated always as (unit_price * quantity) stored,
  primary key (order_id, product_id),
  foreign key (order_id, store_id)
    references public.zerah_orders(id, store_id),
  foreign key (store_id, product_id)
    references public.zerah_inventory(store_id, product_id)
);

create table public.zerah_stock_movements (
  id bigint generated always as identity primary key,
  store_id uuid not null,
  product_id bigint not null,
  order_id uuid references public.zerah_orders(id),
  quantity_delta integer not null check (quantity_delta <> 0),
  reason text not null,
  created_by uuid references auth.users(id),
  created

  create schema if not exists private;

create table public.zerah_stores (
  id uuid primary key,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.zerah_products (
  id bigint primary key,
  sku text not null unique,
  barcode text,
  name text not null,
  category text not null default 'General',
  purchase_cost numeric(12,2),
  selling_price numeric(12,2) not null check (selling_price >= 0),
  minimum_stock integer not null default 0 check (minimum_stock >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.zerah_inventory (
  store_id uuid not null references public.zerah_stores(id),
  product_id bigint not null references public.zerah_products(id),
  quantity_on_hand integer not null default 0 check (quantity_on_hand >= 0),
  updated_at timestamptz not null default now(),
  primary key (store_id, product_id)
);

create table public.zerah_store_memberships (
  store_id uuid not null references public.zerah_stores(id),
  user_id uuid not null references auth.users(id),
  role text not null check (role in ('owner', 'manager', 'cashier')),
  created_at timestamptz not null default now(),
  primary key (store_id, user_id)
);

create table public.zerah_orders (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.zerah_stores(id),
  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'cancelled')),
  total_amount numeric(12,2) not null default 0,
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users(id),
  unique (id, store_id)
);

create table public.zerah_order_items (
  order_id uuid not null,
  store_id uuid not null,
  product_id bigint not null,
  quantity integer not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  unit_cost numeric(12,2),
  line_total numeric(12,2) generated always as (unit_price * quantity) stored,
  primary key (order_id, product_id),
  foreign key (order_id, store_id)
    references public.zerah_orders(id, store_id),
  foreign key (store_id, product_id)
    references public.zerah_inventory(store_id, product_id)
);

create table public.zerah_stock_movements (
  id bigint generated always as identity primary key,
  store_id uuid not null,
  product_id bigint not null,
  order_id uuid references public.zerah_orders(id),
  quantity_change integer not null check (quantity_change <> 0),
  reason text not null,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  foreign key (store_id, product_id)
    references public.zerah_inventory(store_id, product_id)
);

create index zerah_orders_store_status_idx
  on public.zerah_orders(store_id, status, created_at);

create or replace function private.zerah_has_store_role(
  p_store_id uuid,
  p_roles text[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.zerah_store_memberships m
    where m.store_id = p_store_id
      and m.user_id = (select auth.uid())
      and m.role = any (p_roles)
  );
$$;

alter table public.zerah_stores enable row level security;
alter table public.zerah_products enable row level security;
alter table public.zerah_inventory enable row level security;
alter table public.zerah_store_memberships enable row level security;
alter table public.zerah_orders enable row level security;
alter table public.zerah_order_items enable row level security;
alter table public.zerah_stock_movements enable row level security;

create policy "Read active stores"
on public.zerah_stores for select
to anon, authenticated
using (
  is_active
  or private.zerah_has_store_role(id, array['owner', 'manager', 'cashier'])
);

create policy "Read active products"
on public.zerah_products for select
to anon, authenticated
using (is_active);

create policy "Read inventory for active stores"
on public.zerah_inventory for select
to anon, authenticated
using (
  exists (
    select 1 from public.zerah_stores s
    where s.id = store_id and s.is_active
  )
  or private.zerah_has_store_role(store_id, array['owner', 'manager', 'cashier'])
);

create policy "Users read their own store membership"
on public.zerah_store_memberships for select
to authenticated
using (
  user_id = (select auth.uid())
  or private.zerah_has_store_role(store_id, array['owner', 'manager'])
);

create policy "Store team reads orders"
on public.zerah_orders for select
to authenticated
using (
  private.zerah_has_store_role(store_id, array['owner', 'manager', 'cashier'])
);

create policy "Store team reads order items"
on public.zerah_order_items for select
to authenticated
using (
  private.zerah_has_store_role(store_id, array['owner', 'manager', 'cashier'])
);

create policy "Store team reads stock movements"
on public.zerah_stock_movements for select
to authenticated
using (
  private.zerah_has_store_role(store_id, array['owner', 'manager', 'cashier'])
);

grant usage on schema private to anon, authenticated;
grant execute on function private.zerah_has_store_role(uuid, text[])
  to anon, authenticated;

grant select on public.zerah_stores,
  public.zerah_products,
  public.zerah_inventory
to anon, authenticated;

grant select on public.zerah_store_memberships,
  public.zerah_orders,
  public.zerah_order_items,
  public.zerah_stock_movements
to authenticated;

create or replace function private.zerah_create_store_order_impl(
  p_store_id uuid,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order_id uuid;
  v_item_count integer;
  v_inserted_count integer;
begin
  if p_items is null
     or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0
     or jsonb_array_length(p_items) > 50 then
    raise exception 'Add between 1 and 50 items.';
  end if;

  if not exists (
    select 1 from public.zerah_stores s
    where s.id = p_store_id and s.is_active
  ) then
    raise exception 'Store is not available.';
  end if;

  select count(*) into v_item_count
  from jsonb_to_recordset(p_items) as x(product_id bigint, quantity integer)
  where x.product_id is not null and x.quantity > 0;

  if v_item_count <> jsonb_array_length(p_items) then
    raise exception 'Each item needs a product and a positive whole-number quantity.';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_items) as x(product_id bigint, quantity integer)
    group by x.product_id
    having count(*) > 1
  ) then
    raise exception 'A product can appear only once in the order.';
  end if;

  insert into public.zerah_orders(store_id)
  values (p_store_id)
  returning id into v_order_id;

  insert into public.zerah_order_items(
    order_id, store_id, product_id, quantity, unit_price, unit_cost
  )
  select
    v_order_id,
    p_store_id,
    p.id,
    x.quantity,
    p.selling_price,
    p.purchase_cost
  from jsonb_to_recordset(p_items) as x(product_id bigint, quantity integer)
  join public.zerah_products p
    on p.id = x.product_id and p.is_active
  join public.zerah_inventory i
    on i.store_id = p_store_id
   and i.product_id = p.id
   and i.quantity_on_hand >= x.quantity;

  get diagnostics v_inserted_count = row_count;

  if v_inserted_count <> v_item_count then
    raise exception 'A product is unavailable or has insufficient stock.';
  end if;

  update public.zerah_orders o
  set total_amount = (
    select coalesce(sum(oi.line_total), 0)
    from public.zerah_order_items oi
    where oi.order_id = v_order_id
  )
  where o.id = v_order_id;

  return v_order_id;
end;
$$;

create or replace function public.zerah_create_store_order(
  p_store_id uuid,
  p_items jsonb
)
returns uuid
language sql
security invoker
set search_path = ''
as $$
  select private.zerah_create_store_order_impl(p_store_id, p_items);
$$;

create or replace function private.zerah_confirm_store_order_impl(
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
  v_line record;
  v_line_count integer := 0;
begin
  select o.store_id, o.status
    into v_store_id, v_status
  from public.zerah_orders o
  where o.id = p_order_id
  for update;

  if not found then
    raise exception 'Order not found.';
  end if;

  if not private.zerah_has_store_role(
    v_store_id, array['owner', 'manager', 'cashier']
  ) then
    raise exception 'Only an assigned cashier or manager can confirm this order.';
  end if;

  if v_status <> 'pending' then
    raise exception 'This order is no longer pending.';
  end if;

  for v_line in
    select
      oi.product_id,
      oi.quantity,
      p.name,
      i.quantity_on_hand
    from public.zerah_order_items oi
    join public.zerah_inventory i
      on i.store_id = oi.store_id and i.product_id = oi.product_id
    join public.zerah_products p on p.id = oi.product_id
    where oi.order_id = p_order_id
    order by oi.product_id
    for update of i
  loop
    v_line_count := v_line_count + 1;

    if v_line.quantity_on_hand < v_line.quantity then
      raise exception 'Not enough stock remains for %.', v_line.name;
    end if;

    update public.zerah_inventory
    set quantity_on_hand = quantity_on_hand - v_line.quantity,
        updated_at = now()
    where store_id = v_store_id
      and product_id = v_line.product_id;

    insert into public.zerah_stock_movements(
      store_id, product_id, order_id, quantity_change, reason, created_by
    )
    values (
      v_store_id, v_line.product_id, p_order_id,
      -v_line.quantity, 'confirmed_store_order', (select auth.uid())
    );
  end loop;

  if v_line_count = 0 then
    raise exception 'Order has no items.';
  end if;

  update public.zerah_orders
  set status = 'confirmed',
      confirmed_at = now(),
      confirmed_by = (select auth.uid())
  where id = p_order_id;
end;
$$;

create or replace function public.zerah_confirm_store_order(
  p_order_id uuid
)
returns void
language sql
security invoker
set search_path = ''
as $$
  select private.zerah_confirm_store_order_impl(p_order_id);
$$;

revoke all on function private.zerah_create_store_order_impl(uuid, jsonb)
  from public;
revoke all on function private.zerah_confirm_store_order_impl(uuid)
  from public;
grant execute on function private.zerah_create_store_order_impl(uuid, jsonb)
  to anon, authenticated;
grant execute on function private.zerah_confirm_store_order_impl(uuid)
  to authenticated;

revoke all on function public.zerah_create_store_order(uuid, jsonb) from public;
revoke all on function public.zerah_confirm_store_order(uuid) from public;
grant execute on function public.zerah_create_store_order(uuid, jsonb)
  to anon, authenticated;
grant execute on function public.zerah_confirm_store_order(uuid)
  to authenticated;

insert into public.zerah_stores(id, name)
values ('11111111-1111-4111-8111-111111111111', 'ZERAH Demo Store');

insert into public.zerah_products
  (id, sku, name, category, purchase_cost, selling_price, minimum_stock)
values
  (1, 'SKU-1',  'Parle-G Biscuits',       'Biscuits',      8,   10, 8),
  (2, 'SKU-2',  'Coca-Cola 750 ml',       'Drinks',       32,   40, 8),
  (3, 'SKU-3',  'Surf Excel 1 kg',         'Cleaning',    120,  145, 4),
  (4, 'SKU-4',  'Maggi Noodles',           'Snacks',       10,   14, 8),
  (5, 'SKU-5',  'Lux Soap',                'Personal Care',27,   35, 6),
  (6, 'SKU-6',  'Aashirvaad Atta 5 kg',    'Groceries',   240,  280, 4),
  (7, 'SKU-7',  'Amul Milk 500 ml',        'Dairy',        26,   30, 6),
  (8, 'SKU-8',  'Good Day Cookies',        'Biscuits',     24,   30, 5),
  (9, 'SKU-9',  'Tata Salt 1 kg',          'Groceries',    22,   28, 5),
  (10,'SKU-10', 'Colgate Toothpaste',      'Personal Care',50,   65, 5);

insert into public.zerah_inventory(store_id, product_id, quantity_on_hand)
values
  ('11111111-1111-4111-8111-111111111111', 1, 24),
  ('11111111-1111-4111-8111-111111111111', 2, 5),
  ('11111111-1111-4111-8111-111111111111', 3, 0),
  ('11111111-1111-4111-8111-111111111111', 4, 18),
  ('11111111-1111-4111-8111-111111111111', 5, 3),
  ('11111111-1111-4111-8111-111111111111', 6, 12),
  ('11111111-1111-4111-8111-111111111111', 7, 16),
  ('11111111-1111-4111-8111-111111111111', 8, 9),
  ('11111111-1111-4111-8111-111111111111', 9, 20),
  ('11111111-1111-4111-8111-111111111111', 10, 4);