-- Add the editable ComTour service catalogue to an existing Supabase project.
create table if not exists public.catalogue_services (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  description text not null default '',
  unit text not null check(unit in ('Personne','Groupe','Véhicule','Nuit','Prestation')),
  price numeric(18,2) not null check(price>=0),
  currency text not null default 'KMF' check(currency in ('KMF','EUR')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id)
);
alter table public.catalogue_services enable row level security;
drop policy if exists "staff read catalogue" on public.catalogue_services;
create policy "staff read catalogue" on public.catalogue_services for select to authenticated using(public.is_staff());
drop policy if exists "admin and responsable insert catalogue" on public.catalogue_services;
create policy "admin and responsable insert catalogue" on public.catalogue_services for insert to authenticated with check(public.current_role() in ('admin','responsable'));
drop policy if exists "admin and responsable update catalogue" on public.catalogue_services;
create policy "admin and responsable update catalogue" on public.catalogue_services for update to authenticated using(public.current_role() in ('admin','responsable')) with check(public.current_role() in ('admin','responsable'));
drop policy if exists "admin delete catalogue" on public.catalogue_services;
create policy "admin delete catalogue" on public.catalogue_services for delete to authenticated using(public.current_role()='admin');
grant select,insert,update,delete on public.catalogue_services to authenticated;
drop trigger if exists catalogue_services_touch on public.catalogue_services;
create trigger catalogue_services_touch before update on public.catalogue_services for each row execute function public.touch_updated_at();
drop trigger if exists catalogue_services_audit on public.catalogue_services;
create trigger catalogue_services_audit after insert or update or delete on public.catalogue_services for each row execute function public.audit_row();
