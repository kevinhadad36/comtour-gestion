-- Apply in the Supabase SQL editor for a new ComTour project.
create extension if not exists pgcrypto;
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role text not null default 'agent' check (role in ('admin','responsable','comptable','agent')),
  created_at timestamptz not null default now()
);
create or replace function public.current_role() returns text language sql stable security definer set search_path=public as $$ select role from public.profiles where id=auth.uid() $$;
create or replace function public.can_read_finance() returns boolean language sql stable as $$ select coalesce(public.current_role() in ('admin','comptable'),false) $$;
create or replace function public.is_staff() returns boolean language sql stable as $$ select coalesce(public.current_role() in ('admin','responsable','comptable','agent'),false) $$;
create or replace function public.touch_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;
create table if not exists public.clients(id uuid primary key default gen_random_uuid(),full_name text not null,email text,phone text,address text,notes text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),created_by uuid not null default auth.uid() references auth.users(id));
create table if not exists public.suppliers(id uuid primary key default gen_random_uuid(),name text not null,email text,phone text,address text,service_type text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),created_by uuid not null default auth.uid() references auth.users(id));
create table if not exists public.quotes(id uuid primary key default gen_random_uuid(),reference text not null unique,title text not null,client_id uuid references public.clients(id),status text not null default 'brouillon',currency text not null default 'KMF' check(currency in ('KMF','EUR')),exchange_rate numeric(18,6) not null default 1,amount numeric(18,2) not null default 0,accepted_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),created_by uuid not null default auth.uid() references auth.users(id));
create table if not exists public.invoices(id uuid primary key default gen_random_uuid(),reference text not null unique,quote_id uuid references public.quotes(id),client_id uuid references public.clients(id),status text not null default 'impayee',currency text not null default 'KMF' check(currency in ('KMF','EUR')),exchange_rate numeric(18,6) not null default 1,amount numeric(18,2) not null default 0,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),created_by uuid not null default auth.uid() references auth.users(id));
create table if not exists public.missions(id uuid primary key default gen_random_uuid(),reference text not null unique,quote_id uuid references public.quotes(id),client_id uuid references public.clients(id),destination text,start_date date,end_date date,status text not null default 'en_preparation',created_at timestamptz not null default now(),updated_at timestamptz not null default now(),created_by uuid not null default auth.uid() references auth.users(id));
create table if not exists public.expenses(id uuid primary key default gen_random_uuid(),mission_id uuid references public.missions(id),supplier_id uuid references public.suppliers(id),description text not null,category text not null default 'Autres dépenses',amount numeric(18,2) not null check(amount>=0),currency text not null default 'KMF' check(currency in ('KMF','EUR')),exchange_rate numeric(18,6) not null default 1,payer text not null default 'comtour' check(payer in ('comtour','client_advance','client_charge','exceptional')),paid_at date not null default current_date,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),created_by uuid not null default auth.uid() references auth.users(id));
create table if not exists public.payments(id uuid primary key default gen_random_uuid(),invoice_id uuid references public.invoices(id),mission_id uuid references public.missions(id),kind text not null default 'encaissement',amount numeric(18,2) not null check(amount>0),currency text not null default 'KMF' check(currency in ('KMF','EUR')),exchange_rate numeric(18,6) not null default 1,paid_at date not null default current_date,method text,created_at timestamptz not null default now(),created_by uuid not null default auth.uid() references auth.users(id));
create table if not exists public.audit_log(id bigint generated always as identity primary key,table_name text not null,row_id uuid not null,action text not null,old_data jsonb,new_data jsonb,actor uuid default auth.uid(),occurred_at timestamptz not null default now());
do $$ declare t text; begin foreach t in array array['clients','suppliers','quotes','invoices','missions','expenses','payments'] loop execute format('drop trigger if exists %I_touch on public.%I',t,t); execute format('create trigger %I_touch before update on public.%I for each row execute function public.touch_updated_at()',t,t); end loop; end $$;
create or replace function public.audit_row() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into public.audit_log(table_name,row_id,action,old_data,new_data,actor) values(tg_table_name,coalesce(new.id,old.id),tg_op,case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end,case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end,auth.uid()); if tg_op='DELETE' then return old; else return new; end if; end $$;
do $$ declare t text; begin foreach t in array array['clients','suppliers','quotes','invoices','missions','expenses','payments'] loop execute format('drop trigger if exists %I_audit on public.%I',t,t); execute format('create trigger %I_audit after insert or update or delete on public.%I for each row execute function public.audit_row()',t,t); end loop; end $$;
alter table public.profiles enable row level security;
drop policy if exists "profile self or admin read" on public.profiles;
create policy "profile self or admin read" on public.profiles for select to authenticated using(id=auth.uid() or public.current_role()='admin');
drop policy if exists "admin manage profiles" on public.profiles;
create policy "admin manage profiles" on public.profiles for all to authenticated using(public.current_role()='admin') with check(public.current_role()='admin');
do $$ declare t text; begin foreach t in array array['clients','suppliers','quotes','invoices','missions','expenses','payments'] loop execute format('alter table public.%I enable row level security',t); execute format('drop policy if exists "staff read" on public.%I',t); execute format('create policy "staff read" on public.%I for select to authenticated using(public.is_staff())',t); execute format('drop policy if exists "staff insert" on public.%I',t); execute format('create policy "staff insert" on public.%I for insert to authenticated with check(public.is_staff())',t); execute format('drop policy if exists "staff update" on public.%I',t); execute format('create policy "staff update" on public.%I for update to authenticated using(public.is_staff()) with check(public.is_staff())',t); execute format('drop policy if exists "admin delete" on public.%I',t); execute format('create policy "admin delete" on public.%I for delete to authenticated using(public.current_role()=''admin'')',t); end loop; end $$;
alter table public.audit_log enable row level security;
drop policy if exists "authorized audit read" on public.audit_log;
create policy "authorized audit read" on public.audit_log for select to authenticated using(public.current_role() in ('admin','comptable'));
revoke all on public.audit_log from anon,authenticated;
grant select on public.audit_log to authenticated;
grant select,insert,update,delete on public.clients,public.suppliers,public.quotes,public.invoices,public.missions,public.expenses,public.payments to authenticated;
grant select,insert,update,delete on public.profiles to authenticated;
-- Create the first admin account in Supabase Auth, then add its profile row:
-- insert into public.profiles(id,full_name,role) values('<AUTH USER UUID>','Administrateur ComTour','admin');
-- Editable service catalogue.
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
