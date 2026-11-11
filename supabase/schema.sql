-- Frame It Salon SaaS - initial multi-tenant schema
-- Run in the Supabase SQL Editor on a new project.
-- Public booking requests are INSERT-only; customer details are never publicly readable.

create extension if not exists pgcrypto;

create table if not exists public.salons (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete restrict,
  name text not null,
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  description text, logo_url text, hero_image_url text,
  primary_color text not null default '#315b45',
  accent_color text not null default '#d9b97a',
  phone text, email text, whatsapp text, address text,
  instagram_url text, facebook_url text,
  booking_notice text not null default 'Your request is not confirmed until the salon contacts you.',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.salon_members (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references public.salons(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'staff' check (role in ('owner','admin','staff')),
  created_at timestamptz not null default now(),
  unique (salon_id, user_id)
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references public.salons(id) on delete cascade,
  name text not null, description text, category text,
  price numeric(10,2) not null default 0 check (price >= 0),
  duration_minutes integer not null default 30 check (duration_minutes > 0),
  image_url text, is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.staff (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references public.salons(id) on delete cascade,
  name text not null, role_title text, bio text, photo_url text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  salon_id uuid not null references public.salons(id) on delete cascade,
  service_id uuid not null references public.services(id) on delete restrict,
  staff_id uuid references public.staff(id) on delete set null,
  customer_name text not null,
  customer_phone text not null,
  customer_email text,
  requested_date date not null,
  requested_time time not null,
  notes text,
  status text not null default 'pending'
    check (status in ('pending','confirmed','declined','completed','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists salon_members_user_id_idx on public.salon_members(user_id);
create index if not exists services_salon_active_idx on public.services(salon_id, is_active, sort_order);
create index if not exists staff_salon_active_idx on public.staff(salon_id, is_active, sort_order);
create index if not exists bookings_salon_date_idx on public.bookings(salon_id, requested_date, requested_time);

create or replace function public.add_salon_creator_as_owner()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.salon_members (salon_id, user_id, role)
  values (new.id, new.owner_user_id, 'owner')
  on conflict (salon_id, user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists salons_add_creator_owner on public.salons;
create trigger salons_add_creator_owner after insert on public.salons
for each row execute function public.add_salon_creator_as_owner();

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = ''
as $$
begin new.updated_at = now(); return new; end;
$$;

drop trigger if exists salons_set_updated_at on public.salons;
create trigger salons_set_updated_at before update on public.salons
for each row execute function public.set_updated_at();
drop trigger if exists services_set_updated_at on public.services;
create trigger services_set_updated_at before update on public.services
for each row execute function public.set_updated_at();
drop trigger if exists staff_set_updated_at on public.staff;
create trigger staff_set_updated_at before update on public.staff
for each row execute function public.set_updated_at();
drop trigger if exists bookings_set_updated_at on public.bookings;
create trigger bookings_set_updated_at before update on public.bookings
for each row execute function public.set_updated_at();

alter table public.salons enable row level security;
alter table public.salon_members enable row level security;
alter table public.services enable row level security;
alter table public.staff enable row level security;
alter table public.bookings enable row level security;

create or replace function public.is_salon_member(target_salon uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.salon_members m
    where m.salon_id = target_salon and m.user_id = (select auth.uid()));
$$;

create or replace function public.can_manage_salon(target_salon uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.salon_members m
    where m.salon_id = target_salon and m.user_id = (select auth.uid())
      and m.role in ('owner','admin'));
$$;

drop policy if exists "Public can view active salons" on public.salons;
create policy "Public can view active salons" on public.salons
for select using (is_active = true or owner_user_id = (select auth.uid()) or public.is_salon_member(id));

drop policy if exists "Authenticated users can create their own salon" on public.salons;
create policy "Authenticated users can create their own salon" on public.salons
for insert to authenticated with check (owner_user_id = (select auth.uid()));

drop policy if exists "Salon admins can update salon" on public.salons;
create policy "Salon admins can update salon" on public.salons
for update to authenticated using (public.can_manage_salon(id))
with check (public.can_manage_salon(id));

drop policy if exists "Salon owners can delete salon" on public.salons;
create policy "Salon owners can delete salon" on public.salons
for delete to authenticated using (exists (
  select 1 from public.salon_members m
  where m.salon_id = id and m.user_id = (select auth.uid()) and m.role = 'owner'
));

drop policy if exists "Members can view salon memberships" on public.salon_members;
create policy "Members can view salon memberships" on public.salon_members
for select to authenticated using (user_id = (select auth.uid()) or public.can_manage_salon(salon_id));

drop policy if exists "Salon admins can add members" on public.salon_members;
create policy "Salon admins can add members" on public.salon_members
for insert to authenticated with check (public.can_manage_salon(salon_id));

drop policy if exists "Salon admins can update members" on public.salon_members;
create policy "Salon admins can update members" on public.salon_members
for update to authenticated using (public.can_manage_salon(salon_id))
with check (public.can_manage_salon(salon_id));

drop policy if exists "Salon admins can remove members" on public.salon_members;
create policy "Salon admins can remove members" on public.salon_members
for delete to authenticated using (public.can_manage_salon(salon_id));

drop policy if exists "Public can view active services" on public.services;
create policy "Public can view active services" on public.services
for select using (
  (is_active = true and exists (select 1 from public.salons s where s.id = salon_id and s.is_active = true))
  or public.is_salon_member(salon_id)
);
drop policy if exists "Salon members manage services" on public.services;
create policy "Salon members manage services" on public.services
for all to authenticated using (public.is_salon_member(salon_id))
with check (public.is_salon_member(salon_id));

drop policy if exists "Public can view active staff" on public.staff;
create policy "Public can view active staff" on public.staff
for select using (
  (is_active = true and exists (select 1 from public.salons s where s.id = salon_id and s.is_active = true))
  or public.is_salon_member(salon_id)
);
drop policy if exists "Salon members manage staff" on public.staff;
create policy "Salon members manage staff" on public.staff
for all to authenticated using (public.is_salon_member(salon_id))
with check (public.is_salon_member(salon_id));

drop policy if exists "Public can submit pending booking requests" on public.bookings;
create policy "Public can submit pending booking requests" on public.bookings
for insert to anon, authenticated with check (
  status = 'pending'
  and exists (select 1 from public.salons s where s.id = salon_id and s.is_active = true)
  and exists (select 1 from public.services sv
    where sv.id = service_id and sv.salon_id = salon_id and sv.is_active = true)
  and (staff_id is null or exists (select 1 from public.staff st
    where st.id = staff_id and st.salon_id = salon_id and st.is_active = true))
);

drop policy if exists "Salon members can view bookings" on public.bookings;
create policy "Salon members can view bookings" on public.bookings
for select to authenticated using (public.is_salon_member(salon_id));

drop policy if exists "Salon members can update bookings" on public.bookings;
create policy "Salon members can update bookings" on public.bookings
for update to authenticated using (public.is_salon_member(salon_id))
with check (public.is_salon_member(salon_id));

revoke all on public.salon_members from anon;
revoke all on public.bookings from anon;
grant select on public.salons, public.services, public.staff to anon, authenticated;
grant insert, select, update, delete on public.salons to authenticated;
grant select, insert, update, delete on public.salon_members to authenticated;
grant select, insert, update, delete on public.services, public.staff to authenticated;
grant insert on public.bookings to anon, authenticated;
grant select, update on public.bookings to authenticated;
