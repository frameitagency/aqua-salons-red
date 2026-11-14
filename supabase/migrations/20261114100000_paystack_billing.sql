-- Frame It Salon SaaS: Paystack billing foundation
-- Applied to Supabase project liecbgqsvdgyzfiixgji on 2026-11-14.
-- Billing records are backend-only. Do not grant browser roles access.

create table if not exists public.salon_subscriptions (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null unique references public.salons(id) on delete cascade,
  provider text not null default 'paystack' check (provider = 'paystack'),
  plan_code text not null,
  status text not null default 'pending'
    check (status in ('pending','trialing','active','past_due','canceled','inactive')),
  trial_starts_at timestamptz,
  trial_ends_at timestamptz,
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  paystack_customer_code text,
  paystack_subscription_code text,
  last_payment_reference text,
  last_payment_at timestamptz,
  failed_payment_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.paystack_checkout_attempts (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references public.salons(id) on delete cascade,
  initiated_by uuid not null references auth.users(id) on delete restrict,
  reference text not null unique,
  plan_code text not null,
  amount numeric(10,2) not null check (amount > 0),
  currency text not null default 'ZAR' check (currency = 'ZAR'),
  status text not null default 'pending'
    check (status in ('pending','success','failed','abandoned')),
  checkout_url text,
  access_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.paystack_webhook_events (
  id uuid primary key default gen_random_uuid(),
  event_hash text not null unique,
  event_type text not null,
  transaction_reference text,
  subscription_code text,
  processing_status text not null default 'received'
    check (processing_status in ('received','processed','ignored','failed')),
  received_at timestamptz not null default now(),
  processed_at timestamptz
);

create index if not exists salon_subscriptions_status_idx
  on public.salon_subscriptions(status);
create index if not exists paystack_checkout_salon_created_idx
  on public.paystack_checkout_attempts(salon_id, created_at desc);
create index if not exists paystack_webhook_reference_idx
  on public.paystack_webhook_events(transaction_reference);

create or replace function public.set_billing_updated_at()
returns trigger language plpgsql set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists salon_subscriptions_set_updated_at on public.salon_subscriptions;
create trigger salon_subscriptions_set_updated_at
before update on public.salon_subscriptions
for each row execute function public.set_billing_updated_at();

drop trigger if exists paystack_checkout_attempts_set_updated_at on public.paystack_checkout_attempts;
create trigger paystack_checkout_attempts_set_updated_at
before update on public.paystack_checkout_attempts
for each row execute function public.set_billing_updated_at();

alter table public.salon_subscriptions enable row level security;
alter table public.paystack_checkout_attempts enable row level security;
alter table public.paystack_webhook_events enable row level security;

revoke all on public.salon_subscriptions from anon, authenticated;
revoke all on public.paystack_checkout_attempts from anon, authenticated;
revoke all on public.paystack_webhook_events from anon, authenticated;
