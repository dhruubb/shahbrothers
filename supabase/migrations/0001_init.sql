-- =====================================================================
-- Shah Brothers — Supabase schema
-- Tables: users, customers, products, sales, sale_items, payments,
--         bonuses (+ app_settings, commission_rules, invoice_counters)
-- Run this once in the Supabase SQL editor (or `supabase db push`).
-- =====================================================================

set client_min_messages = warning;

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------
do $$ begin
  create type public.user_role as enum ('owner', 'manager', 'salesperson');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.payment_method as enum ('cash', 'upi', 'card');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.payment_mode as enum ('cash', 'upi', 'card', 'split');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.sale_status as enum ('completed', 'cancelled');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.discount_type as enum ('percent', 'amount');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.bonus_status as enum ('approved', 'paid');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.contact_channel as enum ('whatsapp', 'sms', 'telegram', 'email', 'call', 'none');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- Staff profiles (1:1 with auth.users)
-- ---------------------------------------------------------------------
create table if not exists public.users (
  id              uuid primary key references auth.users (id) on delete cascade,
  full_name       text not null,
  email           text not null unique,
  phone           text,
  role            public.user_role not null default 'salesperson',
  monthly_target  numeric(12,2) not null default 0 check (monthly_target >= 0),
  is_active       boolean not null default true,
  joined_on       date not null default current_date,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Store settings (single row)
-- ---------------------------------------------------------------------
create table if not exists public.app_settings (
  id              smallint primary key default 1 check (id = 1),
  store_name      text not null default 'Shah Brothers',
  tagline         text,
  address         text,
  phone           text,
  email           text,
  gstin           text,
  gst_rate        numeric(5,2) not null default 5.00 check (gst_rate >= 0 and gst_rate <= 28),
  invoice_prefix  text not null default 'SB' check (invoice_prefix ~ '^[A-Z0-9]{1,6}$'),
  invoice_footer  text,
  updated_at      timestamptz not null default now()
);
insert into public.app_settings (id) values (1) on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- Commission / bonus rules. The rule with the highest
-- min_achievement_pct that a salesperson reaches applies to the month.
-- ---------------------------------------------------------------------
create table if not exists public.commission_rules (
  id                   uuid primary key default gen_random_uuid(),
  name                 text not null,
  min_achievement_pct  numeric(6,2) not null check (min_achievement_pct >= 0),
  commission_pct       numeric(5,2) not null check (commission_pct >= 0 and commission_pct <= 100),
  flat_bonus           numeric(12,2) not null default 0 check (flat_bonus >= 0),
  is_active            boolean not null default true,
  created_at           timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Customers — includes fields for future WhatsApp/Telegram marketing.
-- Opt-ins can only be true when explicit consent has been recorded.
-- ---------------------------------------------------------------------
create table if not exists public.customers (
  id                        uuid primary key default gen_random_uuid(),
  name                      text not null check (length(trim(name)) > 0),
  phone                     text not null unique check (phone ~ '^[6-9][0-9]{9}$'),
  email                     text,
  city                      text,
  notes                     text,
  date_of_birth             date,
  anniversary               date,
  preferred_language        text not null default 'en',
  preferred_channel         public.contact_channel not null default 'none',
  marketing_consent         boolean not null default false,
  marketing_consent_at      timestamptz,
  marketing_consent_source  text,           -- e.g. in_store_verbal, signed_form, app
  whatsapp_opt_in           boolean not null default false,
  sms_opt_in                boolean not null default false,
  email_opt_in              boolean not null default false,
  telegram_opt_in           boolean not null default false,
  unsubscribed_at           timestamptz,
  tags                      text[] not null default '{}',
  created_by                uuid references public.users (id) on delete set null,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  constraint customers_consent_has_timestamp
    check (not marketing_consent or marketing_consent_at is not null),
  constraint customers_optin_requires_consent
    check (not (whatsapp_opt_in or sms_opt_in or email_opt_in or telegram_opt_in) or marketing_consent)
);
create index if not exists customers_name_idx on public.customers (lower(name));

-- ---------------------------------------------------------------------
-- Products (sarees)
-- ---------------------------------------------------------------------
create table if not exists public.products (
  id             uuid primary key default gen_random_uuid(),
  sku            text not null unique,
  name           text not null,
  category       text not null,
  fabric         text,
  color          text,
  description    text,
  selling_price  numeric(12,2) not null check (selling_price >= 0),
  stock_qty      integer not null default 0,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists products_category_idx on public.products (category);

-- ---------------------------------------------------------------------
-- Sales (invoice header). Linked to salesperson, manager, customer and
-- a unique invoice number.
-- ---------------------------------------------------------------------
create table if not exists public.sales (
  id              uuid primary key default gen_random_uuid(),
  invoice_number  text not null unique,
  customer_id     uuid not null constraint sales_customer_id_fkey references public.customers (id),
  salesperson_id  uuid not null constraint sales_salesperson_id_fkey references public.users (id),
  manager_id      uuid not null constraint sales_manager_id_fkey references public.users (id),
  subtotal        numeric(12,2) not null,
  discount_total  numeric(12,2) not null default 0,
  taxable_amount  numeric(12,2) not null,
  gst_rate        numeric(5,2) not null,
  cgst_amount     numeric(12,2) not null default 0,
  sgst_amount     numeric(12,2) not null default 0,
  gst_amount      numeric(12,2) not null default 0,
  round_off       numeric(6,2) not null default 0,
  total           numeric(12,2) not null check (total >= 0),
  payment_mode    public.payment_mode not null,
  status          public.sale_status not null default 'completed',
  notes           text,
  cancelled_at    timestamptz,
  cancelled_by    uuid constraint sales_cancelled_by_fkey references public.users (id),
  cancel_reason   text,
  created_at      timestamptz not null default now()
);
create index if not exists sales_created_at_idx on public.sales (created_at desc);
create index if not exists sales_salesperson_idx on public.sales (salesperson_id, created_at desc);
create index if not exists sales_customer_idx on public.sales (customer_id);

create table if not exists public.sale_items (
  id               uuid primary key default gen_random_uuid(),
  sale_id          uuid not null references public.sales (id) on delete cascade,
  product_id       uuid references public.products (id) on delete set null,
  product_name     text not null,
  product_code     text not null,
  quantity         integer not null check (quantity > 0),
  unit_price       numeric(12,2) not null check (unit_price >= 0),
  discount_type    public.discount_type not null default 'amount',
  discount_value   numeric(12,2) not null default 0 check (discount_value >= 0),
  discount_amount  numeric(12,2) not null default 0,
  line_total       numeric(12,2) not null,
  position         smallint not null default 0
);
create index if not exists sale_items_sale_idx on public.sale_items (sale_id);

create table if not exists public.payments (
  id           uuid primary key default gen_random_uuid(),
  sale_id      uuid not null references public.sales (id) on delete cascade,
  method       public.payment_method not null,
  amount       numeric(12,2) not null check (amount > 0),
  reference    text,
  received_by  uuid references public.users (id),
  created_at   timestamptz not null default now()
);
create index if not exists payments_sale_idx on public.payments (sale_id);

-- ---------------------------------------------------------------------
-- Bonuses: one row per salesperson per month once the owner finalises it.
-- The current month is always shown as a live projection in the app.
-- ---------------------------------------------------------------------
create table if not exists public.bonuses (
  id                 uuid primary key default gen_random_uuid(),
  salesperson_id     uuid not null references public.users (id),
  period_start       date not null check (extract(day from period_start) = 1),
  sales_amount       numeric(12,2) not null,   -- net sales excl. GST
  target_amount      numeric(12,2) not null,
  achievement_pct    numeric(7,2) not null,
  rule_name          text,
  commission_pct     numeric(5,2) not null,
  commission_amount  numeric(12,2) not null,
  flat_bonus         numeric(12,2) not null default 0,
  total_bonus        numeric(12,2) not null,
  status             public.bonus_status not null default 'approved',
  approved_by        uuid references public.users (id),
  approved_at        timestamptz not null default now(),
  paid_at            timestamptz,
  unique (salesperson_id, period_start)
);

create table if not exists public.invoice_counters (
  fy           text primary key,
  last_number  integer not null default 0
);

-- ---------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists users_touch on public.users;
create trigger users_touch before update on public.users
  for each row execute function public.touch_updated_at();
drop trigger if exists customers_touch on public.customers;
create trigger customers_touch before update on public.customers
  for each row execute function public.touch_updated_at();
drop trigger if exists products_touch on public.products;
create trigger products_touch before update on public.products
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------
-- Role helpers (security definer so policies can read public.users)
-- ---------------------------------------------------------------------
create or replace function public.current_user_role() returns public.user_role
language sql stable security definer set search_path = public as $$
  select role from public.users where id = auth.uid() and is_active
$$;

create or replace function public.is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.current_user_role() = 'owner', false)
$$;

create or replace function public.can_bill() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.current_user_role() in ('owner', 'manager'), false)
$$;

create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select public.current_user_role() is not null
$$;

-- New auth users get a profile. The role comes from app_metadata (which
-- only admins / the service role can set), so a public sign-up can never
-- grant itself access: without an app role the profile is inactive.
create or replace function public.handle_new_auth_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.users (id, full_name, email, phone, role, is_active)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)),
    new.email,
    new.raw_user_meta_data ->> 'phone',
    coalesce((new.raw_app_meta_data ->> 'role')::public.user_role, 'salesperson'),
    (new.raw_app_meta_data ? 'role')
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- ---------------------------------------------------------------------
-- Invoice numbers: PREFIX/YY-YY/00001, one sequence per Indian FY
-- ---------------------------------------------------------------------
create or replace function public.fy_code(ts timestamptz) returns text
language sql stable as $$
  select to_char(make_date(s, 1, 1), 'YY') || '-' || to_char(make_date(s + 1, 1, 1), 'YY')
  from (
    select case when extract(month from (ts at time zone 'Asia/Kolkata')) >= 4
                then extract(year from (ts at time zone 'Asia/Kolkata'))::int
                else extract(year from (ts at time zone 'Asia/Kolkata'))::int - 1 end as s
  ) x
$$;

create or replace function public.next_invoice_number(ts timestamptz default now()) returns text
language plpgsql security definer set search_path = public as $$
declare
  v_fy text := public.fy_code(ts);
  v_n integer;
  v_prefix text;
begin
  select invoice_prefix into v_prefix from public.app_settings where id = 1;
  insert into public.invoice_counters (fy, last_number) values (v_fy, 1)
  on conflict (fy) do update set last_number = public.invoice_counters.last_number + 1
  returning last_number into v_n;
  return coalesce(v_prefix, 'SB') || '/' || v_fy || '/' || lpad(v_n::text, 5, '0');
end $$;

-- ---------------------------------------------------------------------
-- Billing maths, in paise (bigint) to avoid rounding drift.
-- MUST stay identical to lib/domain/billing_calculator.dart.
--   line gross      = qty * unit_price
--   line discount   = percent: round_half_up(gross * pct / 100)
--                     amount : discount value (may not exceed gross)
--   taxable         = subtotal - discount_total
--   gst             = round_half_up(taxable * gst_rate / 100)
--   cgst            = ceil(gst / 2), sgst = gst - cgst
--   total           = taxable + gst rounded half-up to whole rupees
-- ---------------------------------------------------------------------
create or replace function public.line_discount_paise(
  p_gross bigint, p_type public.discount_type, p_value numeric
) returns bigint
language plpgsql immutable as $$
declare
  v_bp bigint;
  v_d bigint;
begin
  if p_value is null or p_value = 0 then return 0; end if;
  if p_value < 0 then raise exception 'Discount cannot be negative'; end if;
  if p_type = 'percent' then
    if p_value > 100 then raise exception 'Discount cannot exceed 100%%'; end if;
    v_bp := round(p_value * 100)::bigint;
    return (p_gross * v_bp + 5000) / 10000;
  end if;
  v_d := round(p_value * 100)::bigint;
  if v_d > p_gross then raise exception 'Discount is more than the item value'; end if;
  return v_d;
end $$;

-- Internal: validates + stores a sale. Not callable by app users.
create or replace function public.create_sale_internal(
  payload jsonb, p_manager uuid, p_created_at timestamptz
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_cust jsonb := coalesce(payload -> 'customer', '{}'::jsonb);
  v_sp uuid := nullif(payload ->> 'salesperson_id', '')::uuid;
  v_customer_id uuid;
  v_gst_rate numeric(5,2);
  v_gst_bp bigint;
  v_item jsonb;
  v_pay jsonb;
  v_qty integer;
  v_price bigint;
  v_gross bigint;
  v_disc bigint;
  v_subtotal bigint := 0;
  v_disc_total bigint := 0;
  v_taxable bigint;
  v_gst bigint;
  v_cgst bigint;
  v_pre bigint;
  v_total bigint;
  v_pay_sum bigint := 0;
  v_pay_amt bigint;
  v_methods text[] := '{}';
  v_mode public.payment_mode;
  v_sale_id uuid := gen_random_uuid();
  v_pos integer := 0;
  v_invoice text;
begin
  if not exists (select 1 from public.users where id = v_sp and role = 'salesperson' and is_active) then
    raise exception 'Select a valid salesperson for this bill';
  end if;

  -- Customer: existing id, or find/create by phone
  if nullif(v_cust ->> 'id', '') is not null then
    select id into v_customer_id from public.customers where id = (v_cust ->> 'id')::uuid;
    if v_customer_id is null then raise exception 'Customer not found'; end if;
  else
    if coalesce(v_cust ->> 'phone', '') !~ '^[6-9][0-9]{9}$' then
      raise exception 'Enter a valid 10-digit mobile number';
    end if;
    if length(trim(coalesce(v_cust ->> 'name', ''))) = 0 then
      raise exception 'Customer name is required';
    end if;
    insert into public.customers (name, phone, created_by)
    values (trim(v_cust ->> 'name'), v_cust ->> 'phone', p_manager)
    on conflict (phone) do update set updated_at = now()
    returning id into v_customer_id;
  end if;

  select gst_rate into v_gst_rate from public.app_settings where id = 1;
  v_gst_rate := coalesce(v_gst_rate, 0);
  v_gst_bp := round(v_gst_rate * 100)::bigint;

  if jsonb_array_length(coalesce(payload -> 'items', '[]'::jsonb)) = 0 then
    raise exception 'Add at least one saree to the bill';
  end if;

  -- Pass 1: totals
  for v_item in select * from jsonb_array_elements(payload -> 'items') loop
    v_qty := (v_item ->> 'quantity')::integer;
    if v_qty is null or v_qty <= 0 then raise exception 'Quantity must be at least 1'; end if;
    v_price := round((v_item ->> 'unit_price')::numeric * 100)::bigint;
    if v_price < 0 then raise exception 'Price cannot be negative'; end if;
    v_gross := v_qty * v_price;
    v_disc := public.line_discount_paise(
      v_gross,
      coalesce(v_item ->> 'discount_type', 'amount')::public.discount_type,
      coalesce((v_item ->> 'discount_value')::numeric, 0));
    v_subtotal := v_subtotal + v_gross;
    v_disc_total := v_disc_total + v_disc;
  end loop;

  v_taxable := v_subtotal - v_disc_total;
  v_gst := (v_taxable * v_gst_bp + 5000) / 10000;
  v_cgst := (v_gst + 1) / 2;
  v_pre := v_taxable + v_gst;
  v_total := ((v_pre + 50) / 100) * 100;

  -- Payments must add up exactly
  for v_pay in select * from jsonb_array_elements(coalesce(payload -> 'payments', '[]'::jsonb)) loop
    v_pay_amt := round((v_pay ->> 'amount')::numeric * 100)::bigint;
    if v_pay_amt <= 0 then raise exception 'Payment amounts must be positive'; end if;
    v_pay_sum := v_pay_sum + v_pay_amt;
    if not ((v_pay ->> 'method') = any (v_methods)) then
      v_methods := v_methods || (v_pay ->> 'method');
    end if;
  end loop;
  if cardinality(v_methods) = 0 then raise exception 'Record at least one payment'; end if;
  if v_pay_sum <> v_total then
    raise exception 'Payments (Rs %) do not match the bill total (Rs %)',
      to_char(v_pay_sum / 100.0, 'FM999999990.00'), to_char(v_total / 100.0, 'FM999999990.00');
  end if;
  if cardinality(v_methods) = 1 and jsonb_array_length(payload -> 'payments') = 1 then
    v_mode := v_methods[1]::public.payment_mode;
  else
    v_mode := 'split';
  end if;

  v_invoice := public.next_invoice_number(p_created_at);

  insert into public.sales (
    id, invoice_number, customer_id, salesperson_id, manager_id,
    subtotal, discount_total, taxable_amount, gst_rate,
    cgst_amount, sgst_amount, gst_amount, round_off, total,
    payment_mode, notes, created_at)
  values (
    v_sale_id, v_invoice, v_customer_id, v_sp, p_manager,
    v_subtotal / 100.0, v_disc_total / 100.0, v_taxable / 100.0, v_gst_rate,
    v_cgst / 100.0, (v_gst - v_cgst) / 100.0, v_gst / 100.0, (v_total - v_pre) / 100.0, v_total / 100.0,
    v_mode, nullif(trim(coalesce(payload ->> 'notes', '')), ''), p_created_at);

  -- Pass 2: lines + stock
  for v_item in select * from jsonb_array_elements(payload -> 'items') loop
    v_qty := (v_item ->> 'quantity')::integer;
    v_price := round((v_item ->> 'unit_price')::numeric * 100)::bigint;
    v_gross := v_qty * v_price;
    v_disc := public.line_discount_paise(
      v_gross,
      coalesce(v_item ->> 'discount_type', 'amount')::public.discount_type,
      coalesce((v_item ->> 'discount_value')::numeric, 0));
    insert into public.sale_items (
      sale_id, product_id, product_name, product_code, quantity, unit_price,
      discount_type, discount_value, discount_amount, line_total, position)
    values (
      v_sale_id, nullif(v_item ->> 'product_id', '')::uuid,
      coalesce(nullif(trim(v_item ->> 'product_name'), ''), 'Saree'),
      coalesce(nullif(trim(v_item ->> 'product_code'), ''), '-'),
      v_qty, v_price / 100.0,
      coalesce(v_item ->> 'discount_type', 'amount')::public.discount_type,
      coalesce((v_item ->> 'discount_value')::numeric, 0),
      v_disc / 100.0, (v_gross - v_disc) / 100.0, v_pos);
    v_pos := v_pos + 1;
    if nullif(v_item ->> 'product_id', '') is not null then
      update public.products set stock_qty = stock_qty - v_qty
      where id = (v_item ->> 'product_id')::uuid;
    end if;
  end loop;

  for v_pay in select * from jsonb_array_elements(payload -> 'payments') loop
    insert into public.payments (sale_id, method, amount, reference, received_by, created_at)
    values (v_sale_id, (v_pay ->> 'method')::public.payment_method,
            round((v_pay ->> 'amount')::numeric * 100) / 100.0,
            nullif(trim(coalesce(v_pay ->> 'reference', '')), ''), p_manager, p_created_at);
  end loop;

  return v_sale_id;
end $$;

-- Public RPC used by the app: owners and managers only.
create or replace function public.create_sale(payload jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
begin
  if not public.can_bill() then
    raise exception 'Only owners and managers can create bills' using errcode = '42501';
  end if;
  return public.create_sale_internal(payload, auth.uid(), now());
end $$;

create or replace function public.cancel_sale(p_sale_id uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then
    raise exception 'Only the owner can cancel invoices' using errcode = '42501';
  end if;
  if length(trim(coalesce(p_reason, ''))) = 0 then
    raise exception 'A reason is required to cancel an invoice';
  end if;
  update public.products p set stock_qty = p.stock_qty + si.quantity
  from public.sale_items si, public.sales s
  where si.sale_id = p_sale_id and s.id = si.sale_id and s.status = 'completed'
    and p.id = si.product_id;
  update public.sales
     set status = 'cancelled', cancelled_at = now(), cancelled_by = auth.uid(), cancel_reason = trim(p_reason)
   where id = p_sale_id and status = 'completed';
  if not found then raise exception 'Invoice not found or already cancelled'; end if;
end $$;

-- ---------------------------------------------------------------------
-- Bonuses. MUST stay identical to lib/domain/bonus_calculator.dart.
-- Base = net sales (taxable amount, excl. GST) of completed bills in the
-- calendar month (Asia/Kolkata).
-- ---------------------------------------------------------------------
create or replace function public.finalize_bonuses_internal(p_period date, p_by uuid)
returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_start timestamptz := (date_trunc('month', p_period)::timestamp) at time zone 'Asia/Kolkata';
  v_end   timestamptz := ((date_trunc('month', p_period) + interval '1 month')::timestamp) at time zone 'Asia/Kolkata';
  r record;
  v_rule record;
  v_base bigint;
  v_target bigint;
  v_comm bigint;
  v_flat bigint;
  v_count integer := 0;
begin
  for r in
    select u.id, u.monthly_target,
           coalesce((select sum(round(s.taxable_amount * 100))::bigint from public.sales s
                     where s.salesperson_id = u.id and s.status = 'completed'
                       and s.created_at >= v_start and s.created_at < v_end), 0) as base
    from public.users u where u.role = 'salesperson'
  loop
    v_base := r.base;
    v_target := round(r.monthly_target * 100)::bigint;
    select * into v_rule from public.commission_rules c
     where c.is_active
       and (c.min_achievement_pct = 0
            or (v_target > 0 and v_base * 10000 >= round(c.min_achievement_pct * 100)::bigint * v_target))
     order by c.min_achievement_pct desc limit 1;
    if v_rule is null then
      v_comm := 0; v_flat := 0;
    else
      v_comm := (v_base * round(v_rule.commission_pct * 100)::bigint + 5000) / 10000;
      v_flat := round(v_rule.flat_bonus * 100)::bigint;
    end if;
    insert into public.bonuses (
      salesperson_id, period_start, sales_amount, target_amount, achievement_pct,
      rule_name, commission_pct, commission_amount, flat_bonus, total_bonus, status, approved_by)
    values (
      r.id, date_trunc('month', p_period)::date, v_base / 100.0, v_target / 100.0,
      case when v_target > 0 then round(v_base * 100.0 / v_target, 2) else 0 end,
      v_rule.name, coalesce(v_rule.commission_pct, 0), v_comm / 100.0, v_flat / 100.0,
      (v_comm + v_flat) / 100.0, 'approved', p_by)
    on conflict (salesperson_id, period_start) do update set
      sales_amount = excluded.sales_amount, target_amount = excluded.target_amount,
      achievement_pct = excluded.achievement_pct, rule_name = excluded.rule_name,
      commission_pct = excluded.commission_pct, commission_amount = excluded.commission_amount,
      flat_bonus = excluded.flat_bonus, total_bonus = excluded.total_bonus,
      approved_by = excluded.approved_by, approved_at = now()
    where public.bonuses.status = 'approved';
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;

create or replace function public.finalize_bonuses(p_period date) returns integer
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then
    raise exception 'Only the owner can finalise bonuses' using errcode = '42501';
  end if;
  if date_trunc('month', p_period) >= date_trunc('month', (now() at time zone 'Asia/Kolkata')) then
    raise exception 'Only completed months can be finalised';
  end if;
  return public.finalize_bonuses_internal(p_period, auth.uid());
end $$;

-- ---------------------------------------------------------------------
-- Customer stats view (respects RLS of the caller)
-- ---------------------------------------------------------------------
create or replace view public.customer_stats with (security_invoker = on) as
select c.id as customer_id,
       count(s.id) filter (where s.status = 'completed')                      as purchase_count,
       coalesce(sum(s.total) filter (where s.status = 'completed'), 0)        as total_spent,
       max(s.created_at) filter (where s.status = 'completed')                as last_purchase_at
from public.customers c
left join public.sales s on s.customer_id = c.id
group by c.id;

-- ---------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------
alter table public.users            enable row level security;
alter table public.app_settings     enable row level security;
alter table public.commission_rules enable row level security;
alter table public.customers        enable row level security;
alter table public.products         enable row level security;
alter table public.sales            enable row level security;
alter table public.sale_items       enable row level security;
alter table public.payments         enable row level security;
alter table public.bonuses          enable row level security;
alter table public.invoice_counters enable row level security;  -- no policies: no client access

-- users
drop policy if exists users_select on public.users;
create policy users_select on public.users for select to authenticated
  using (public.is_staff() or id = auth.uid());
drop policy if exists users_owner_write on public.users;
create policy users_owner_write on public.users for update to authenticated
  using (public.is_owner()) with check (public.is_owner());

-- settings & rules: everyone on staff reads, owner writes
drop policy if exists settings_select on public.app_settings;
create policy settings_select on public.app_settings for select to authenticated using (public.is_staff());
drop policy if exists settings_update on public.app_settings;
create policy settings_update on public.app_settings for update to authenticated
  using (public.is_owner()) with check (public.is_owner());

drop policy if exists rules_select on public.commission_rules;
create policy rules_select on public.commission_rules for select to authenticated using (public.is_staff());
drop policy if exists rules_owner_all on public.commission_rules;
create policy rules_owner_all on public.commission_rules for all to authenticated
  using (public.is_owner()) with check (public.is_owner());

-- customers: owner/manager full; salesperson only their own customers
drop policy if exists customers_select on public.customers;
create policy customers_select on public.customers for select to authenticated
  using (public.can_bill() or exists (
    select 1 from public.sales s where s.customer_id = customers.id and s.salesperson_id = auth.uid()));
drop policy if exists customers_insert on public.customers;
create policy customers_insert on public.customers for insert to authenticated with check (public.can_bill());
drop policy if exists customers_update on public.customers;
create policy customers_update on public.customers for update to authenticated
  using (public.can_bill()) with check (public.can_bill());
drop policy if exists customers_delete on public.customers;
create policy customers_delete on public.customers for delete to authenticated using (public.is_owner());

-- products
drop policy if exists products_select on public.products;
create policy products_select on public.products for select to authenticated using (public.is_staff());
drop policy if exists products_insert on public.products;
create policy products_insert on public.products for insert to authenticated with check (public.can_bill());
drop policy if exists products_update on public.products;
create policy products_update on public.products for update to authenticated
  using (public.can_bill()) with check (public.can_bill());
drop policy if exists products_delete on public.products;
create policy products_delete on public.products for delete to authenticated using (public.is_owner());

-- sales: written only through create_sale / cancel_sale RPCs
drop policy if exists sales_select on public.sales;
create policy sales_select on public.sales for select to authenticated
  using (public.can_bill() or salesperson_id = auth.uid());

drop policy if exists sale_items_select on public.sale_items;
create policy sale_items_select on public.sale_items for select to authenticated
  using (exists (select 1 from public.sales s where s.id = sale_items.sale_id));

drop policy if exists payments_select on public.payments;
create policy payments_select on public.payments for select to authenticated
  using (exists (select 1 from public.sales s where s.id = payments.sale_id));

-- bonuses: owner manages; salesperson reads own
drop policy if exists bonuses_select on public.bonuses;
create policy bonuses_select on public.bonuses for select to authenticated
  using (public.is_owner() or salesperson_id = auth.uid());
drop policy if exists bonuses_owner_update on public.bonuses;
create policy bonuses_owner_update on public.bonuses for update to authenticated
  using (public.is_owner()) with check (public.is_owner());

-- ---------------------------------------------------------------------
-- Function privileges
-- ---------------------------------------------------------------------
revoke all on function public.create_sale_internal(jsonb, uuid, timestamptz) from public;
revoke all on function public.finalize_bonuses_internal(date, uuid) from public;
revoke all on function public.next_invoice_number(timestamptz) from public;
revoke all on function public.handle_new_auth_user() from public;
do $$ begin
  execute 'revoke all on function public.create_sale_internal(jsonb, uuid, timestamptz) from anon, authenticated';
  execute 'revoke all on function public.finalize_bonuses_internal(date, uuid) from anon, authenticated';
  execute 'revoke all on function public.next_invoice_number(timestamptz) from anon, authenticated';
exception when undefined_object then null; end $$;
grant execute on function public.create_sale(jsonb) to authenticated;
grant execute on function public.cancel_sale(uuid, text) to authenticated;
grant execute on function public.finalize_bonuses(date) to authenticated;
