# Frame It Salon SaaS

A multi-tenant salon website and management platform built from the existing Adora demo website.

**Adora is demo content, not the platform brand.** Each salon will have its own name, logo, colours, services, prices, gallery, staff, contact information and booking requests.

## MVP scope

1. Salon owner registration and sign-in.
2. Create a salon profile with a unique URL slug.
3. Salon dashboard for branding, contact details, services and staff.
4. Public salon page resolved by slug.
5. Customer appointment requests.
6. Private booking inbox for salon members.
7. Frame It platform administration (later milestone).

## Stack

- Existing HTML/CSS/JavaScript salon template as the public-site design starting point.
- Supabase Auth for accounts.
- Supabase Postgres with Row Level Security for tenant separation.
- Supabase Storage for salon logos and gallery images.
- Vercel or another host with wildcard subdomain support for deployment.

## Database setup

1. Create a Supabase project.
2. Open SQL Editor.
3. Run the file supabase/schema.sql.
4. In Authentication > URL Configuration, set your local and production redirect URLs.
5. Create a browser client using the Supabase project URL and publishable/anon key.

Never put a Supabase service-role key in browser code. Only the publishable/anon key belongs in a public frontend; Row Level Security must remain enabled.

## Tenant model

Each salon has a row in public.salons and a unique slug. Related services, staff and bookings carry salon_id. Salon membership determines which signed-in users can manage a tenant. Public visitors can read active salon information, active services and active staff, and can submit a pending booking request. They cannot read booking records or salon memberships.

The first user who creates a salon becomes its owner through a database trigger.

## Local development

Both `dashboard.html` and the public `index.html` are now connected to the `frame-it-salon-saas` Supabase project. The public page reads `?salon=<slug>`, loads the active salon profile, services and staff, and inserts customer requests into `bookings` with `pending` status. The dashboard is used to create the salon and add its services. Demo-only gallery, review and package sections are hidden on tenant pages until those features have salon-specific management.

## Public website testing

1. Create a salon account in `dashboard.html` and create its profile with a unique slug.
2. Add at least one active service in the dashboard.
3. Open the public website with `index.html?salon=your-slug` (replace `your-slug` with the exact slug).
4. Submit a test booking request. It should appear in the dashboard booking inbox as `pending`.

The public page currently uses query-parameter tenant routing for MVP testing. It is not deployed publicly yet.

## Deployment notes

For salon-slug.yourdomain.co.za, configure a wildcard DNS record and a hosting platform that supports wildcard domains. Configure SSL for the root and wildcard domain. A custom domain per salon can be added later.

## Important limitations

- The initial booking flow is a request, not an automatically confirmed appointment.
- Calendar availability, double-booking prevention, reminders, online payments, subscription billing and platform admin tools are not implemented yet.
- Review South Africa's POPIA requirements before collecting real customer information. Publish an appropriate privacy notice and retention policy.
