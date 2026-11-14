-- Enforce paid access for salon management features.
-- Public salon pages and public pending booking inserts remain available.

create or replace function private.has_paid_salon_access(target_salon uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.salon_subscriptions s
    where s.salon_id = target_salon
      and (
        (s.status = 'active' and (s.current_period_end is null or s.current_period_end > now()))
        or (s.status = 'trialing' and s.trial_ends_at is not null and s.trial_ends_at > now())
        or (s.status = 'past_due' and s.grace_ends_at is not null and s.grace_ends_at > now())
      )
  );
$function$;

create or replace function private.can_manage_salon(target_salon uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select
    private.has_paid_salon_access(target_salon)
    and exists (
      select 1
      from public.salon_members m
      where m.salon_id = target_salon
        and m.user_id = (select auth.uid())
        and m.role in ('owner','admin')
    );
$function$;

drop policy if exists "Salon members can view bookings" on public.bookings;
create policy "Paid salon managers can view bookings"
on public.bookings for select to authenticated
using (private.can_manage_salon(salon_id));

drop policy if exists "Salon managers upload salon media" on storage.objects;
create policy "Paid salon managers upload salon media"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'salon-media'
  and private.can_manage_salon((storage.foldername(name))[1]::uuid)
);

drop policy if exists "Salon managers update salon media" on storage.objects;
create policy "Paid salon managers update salon media"
on storage.objects for update to authenticated
using (
  bucket_id = 'salon-media'
  and private.can_manage_salon((storage.foldername(name))[1]::uuid)
)
with check (
  bucket_id = 'salon-media'
  and private.can_manage_salon((storage.foldername(name))[1]::uuid)
);

drop policy if exists "Salon managers delete salon media" on storage.objects;
create policy "Paid salon managers delete salon media"
on storage.objects for delete to authenticated
using (
  bucket_id = 'salon-media'
  and private.can_manage_salon((storage.foldername(name))[1]::uuid)
);
