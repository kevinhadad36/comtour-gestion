-- Additive migration: detailed quotes, mission changes, recurring costs and finance views.
-- Safe to re-run. Existing operational records are retained.

create table if not exists public.quote_items (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes(id) on delete cascade,
  service_id uuid references public.catalogue_services(id) on delete set null,
  description text not null,
  quantity numeric(12,2) not null default 1 check (quantity > 0),
  unit text not null default 'Prestation',
  unit_price numeric(18,2) not null check (unit_price >= 0),
  service_fee numeric(18,2) not null default 0 check (service_fee >= 0),
  currency text not null default 'KMF' check (currency in ('KMF','EUR')),
  exchange_rate numeric(18,6) not null default 1 check (exchange_rate > 0),
  line_total numeric(18,2) generated always as (quantity * unit_price + service_fee) stored,
  created_at timestamptz not null default now()
);

alter table public.quotes add column if not exists deposit_percent numeric(5,2) not null default 50;
alter table public.quotes add column if not exists service_clause text not null default 'Le présent devis couvre exclusivement les prestations et services qui y sont expressément mentionnés. Toute prestation supplémentaire, activité additionnelle, modification du programme, prolongation de séjour ou demande particulière formulée par le client après validation du devis initial fera l’objet d’une facturation complémentaire. Le montant de ces prestations supplémentaires sera communiqué au client avant leur réalisation et soumis à son accord préalable. Les frais correspondants seront ajoutés au montant initial et feront l’objet d’une facture complémentaire ou d’une régularisation de la facture existante. Toute dépense exceptionnelle non prévue dans le devis initial et imputable au client devra également lui être communiquée et justifiée.';
alter table public.quotes add column if not exists accepted_at timestamptz;
alter table public.quotes add column if not exists accepted_by text;
alter table public.invoices add column if not exists kind text not null default 'standard' check (kind in ('standard','acompte','solde','complementaire'));
alter table public.invoices add column if not exists due_date date;
alter table public.invoices add column if not exists service_clause text;
alter table public.invoices add column if not exists description text not null default '';
alter table public.invoices add column if not exists mission_id uuid references public.missions(id);
alter table public.expenses add column if not exists receipt_path text;
alter table public.expenses add column if not exists is_paid boolean not null default true;
alter table public.payments add column if not exists receipt_reference text;
alter table public.payments add column if not exists supplier_id uuid references public.suppliers(id);

create table if not exists public.mission_adjustments (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null references public.missions(id),
  kind text not null default 'supplement' check (kind in ('supplement','reduction','annulation','remboursement')),
  title text not null,
  description text not null default '',
  quantity numeric(12,2) not null default 1 check (quantity > 0),
  unit_price numeric(18,2) not null default 0 check (unit_price >= 0),
  service_fee numeric(18,2) not null default 0 check (service_fee >= 0),
  currency text not null default 'KMF' check (currency in ('KMF','EUR')),
  exchange_rate numeric(18,6) not null default 1 check (exchange_rate > 0),
  total numeric(18,2) not null default 0,
  client_status text not null default 'à_valider' check (client_status in ('à_valider','accepté','refusé')),
  reason text not null default '',
  accepted_at timestamptz,
  accepted_by text,
  document_path text,
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id)
);
alter table public.invoices add column if not exists adjustment_id uuid references public.mission_adjustments(id);
create unique index if not exists invoices_adjustment_unique on public.invoices(adjustment_id) where adjustment_id is not null;

create table if not exists public.mission_events (
  id bigint generated always as identity primary key,
  mission_id uuid not null references public.missions(id),
  event_type text not null,
  description text not null,
  amount numeric(18,2),
  currency text not null default 'KMF',
  metadata jsonb not null default '{}'::jsonb,
  actor uuid default auth.uid(),
  occurred_at timestamptz not null default now()
);

create table if not exists public.recurring_charges (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null,
  amount numeric(18,2) not null check (amount >= 0),
  currency text not null default 'KMF' check (currency in ('KMF','EUR')),
  exchange_rate numeric(18,6) not null default 1 check (exchange_rate > 0),
  due_day smallint not null default 1 check (due_day between 1 and 31),
  start_date date not null default current_date,
  end_date date,
  active boolean not null default true,
  supplier_id uuid references public.suppliers(id),
  created_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id)
);

create table if not exists public.recurring_charge_runs (
  id uuid primary key default gen_random_uuid(),
  recurring_charge_id uuid not null references public.recurring_charges(id),
  month date not null,
  expense_id uuid references public.expenses(id),
  generated_at timestamptz not null default now(),
  unique(recurring_charge_id,month)
);

create table if not exists public.company_settings (
  id integer primary key default 1 check (id = 1),
  company_name text not null default 'Agence ComTour',
  address text not null default 'Moroni, Grande Comore, Union des Comores',
  phone text not null default '',
  email text not null default '',
  logo_path text,
  eur_to_kmf numeric(18,6) not null default 492 check (eur_to_kmf > 0),
  service_clause text not null default 'Le présent devis couvre exclusivement les prestations et services qui y sont expressément mentionnés. Toute prestation supplémentaire, activité additionnelle, modification du programme, prolongation de séjour ou demande particulière formulée par le client après validation du devis initial fera l’objet d’une facturation complémentaire. Le montant de ces prestations supplémentaires sera communiqué au client avant leur réalisation et soumis à son accord préalable. Les frais correspondants seront ajoutés au montant initial et feront l’objet d’une facture complémentaire ou d’une régularisation de la facture existante. Toute dépense exceptionnelle non prévue dans le devis initial et imputable au client devra également lui être communiquée et justifiée.',
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid() references auth.users(id)
);
alter table public.company_settings add column if not exists opening_cash_kmf numeric(18,2) not null default 0;
insert into public.company_settings(id) values (1) on conflict (id) do nothing;

-- Preserve the quote -> mission -> invoice -> payment chain even when an
-- invoice or its first payment predates the mission record.
update public.invoices i set mission_id=m.id
from public.missions m
where i.mission_id is null and i.quote_id=m.quote_id;
update public.payments p set mission_id=coalesce(i.mission_id,m.id)
from public.invoices i
left join public.missions m on m.quote_id=i.quote_id
where p.invoice_id=i.id and p.mission_id is null and coalesce(i.mission_id,m.id) is not null;

create or replace function public.attach_payment_to_mission() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  if new.mission_id is null and new.invoice_id is not null then
    select coalesce(i.mission_id,m.id) into new.mission_id
    from public.invoices i
    left join public.missions m on m.quote_id=i.quote_id
    where i.id=new.invoice_id
    limit 1;
  end if;
  return new;
end $$;
drop trigger if exists payments_attach_mission on public.payments;
create trigger payments_attach_mission before insert or update of invoice_id,mission_id on public.payments
for each row execute function public.attach_payment_to_mission();

-- Extend the append-only audit journal to the financial tables introduced here.
do $$ declare t text; begin
  foreach t in array array['quote_items','mission_adjustments','recurring_charges','recurring_charge_runs'] loop
    execute format('drop trigger if exists %I_audit on public.%I',t,t);
    execute format('create trigger %I_audit after insert or update or delete on public.%I for each row execute function public.audit_row()',t,t);
  end loop;
end $$;

create or replace function public.comtour_audit_event() returns trigger
language plpgsql security definer set search_path=public as $$
declare payload jsonb; v_mission uuid;
begin
  if tg_op = 'INSERT' then
    payload := to_jsonb(new);
    v_mission := nullif(payload->>'mission_id','')::uuid;
  end if;
  if tg_op = 'INSERT' and v_mission is not null then
    insert into public.mission_events(mission_id,event_type,description,amount,currency,metadata)
    values(v_mission, lower(tg_table_name)||'_created', 'Nouvelle opération enregistrée',
      case when payload ? 'amount' then (payload->>'amount')::numeric else null end,
      coalesce(payload->>'currency','KMF'), jsonb_build_object('table',tg_table_name,'row_id',payload->>'id'));
  end if;
  return new;
end $$;

drop view if exists public.mission_financial_summary;
create view public.mission_financial_summary with (security_invoker=true) as
select m.id as mission_id, m.reference, m.client_id, m.quote_id,
  coalesce(q.amount * q.exchange_rate,0) as initial_quote_kmf,
  coalesce((select sum(case when a.kind in ('reduction','annulation','remboursement') then -a.total else a.total end * a.exchange_rate)
    from public.mission_adjustments a where a.mission_id=m.id and a.client_status='accepté'),0) as accepted_changes_kmf,
  coalesce(q.amount * q.exchange_rate,0) + coalesce((select sum(case when a.kind in ('reduction','annulation','remboursement') then -a.total else a.total end * a.exchange_rate)
    from public.mission_adjustments a where a.mission_id=m.id and a.client_status='accepté'),0) as sold_total_kmf,
  coalesce((select sum(p.amount*p.exchange_rate*case when p.kind='remboursement' then -1 else 1 end)
    from public.payments p where p.mission_id=m.id and p.kind in ('encaissement','avance_client','remboursement')),0) as collected_kmf,
  greatest(0,coalesce(q.amount*q.exchange_rate,0) + coalesce((select sum(case when a.kind in ('reduction','annulation','remboursement') then -a.total else a.total end*a.exchange_rate) from public.mission_adjustments a where a.mission_id=m.id and a.client_status='accepté'),0)
    - coalesce((select sum(p.amount*p.exchange_rate*case when p.kind='remboursement' then -1 else 1 end) from public.payments p where p.mission_id=m.id and p.kind in ('encaissement','avance_client','remboursement')),0)) as receivable_kmf,
  coalesce((select sum(e.amount*e.exchange_rate) from public.expenses e where e.mission_id=m.id and e.payer in ('comtour','exceptional')) ,0) as comtour_costs_kmf,
  coalesce((select sum(e.amount*e.exchange_rate) from public.expenses e where e.mission_id=m.id and e.payer='client_advance'),0) as client_advances_kmf,
  coalesce((select sum(e.amount*e.exchange_rate) from public.expenses e where e.mission_id=m.id and e.payer='client_charge'),0) as client_billable_expenses_kmf,
  (coalesce(q.amount*q.exchange_rate,0) + coalesce((select sum(case when a.kind in ('reduction','annulation','remboursement') then -a.total else a.total end*a.exchange_rate) from public.mission_adjustments a where a.mission_id=m.id and a.client_status='accepté'),0)
   - coalesce((select sum(e.amount*e.exchange_rate) from public.expenses e where e.mission_id=m.id and e.payer in ('comtour','exceptional')),0)) as estimated_profit_kmf
from public.missions m left join public.quotes q on q.id=m.quote_id;

create or replace function public.prevent_validated_quote_changes() returns trigger language plpgsql as $$
begin
  if old.status='validé' then raise exception 'Un devis validé est archivé et ne peut plus être modifié. Créez une opération complémentaire.'; end if;
  return new;
end $$;
drop trigger if exists quotes_prevent_validated_edits on public.quotes;
create trigger quotes_prevent_validated_edits before update on public.quotes for each row execute function public.prevent_validated_quote_changes();

create or replace function public.prevent_validated_quote_item_changes() returns trigger language plpgsql as $$
declare v_quote uuid; v_status text;
begin
  v_quote := case when tg_op='DELETE' then old.quote_id else new.quote_id end;
  select status into v_status from public.quotes where id=v_quote;
  if v_status='validé' then raise exception 'Les lignes d’un devis validé ne peuvent pas être modifiées.'; end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;
drop trigger if exists quote_items_prevent_validated_edits on public.quote_items;
create trigger quote_items_prevent_validated_edits before update or delete on public.quote_items for each row execute function public.prevent_validated_quote_item_changes();

alter table public.quote_items enable row level security;
alter table public.mission_adjustments enable row level security;
alter table public.mission_events enable row level security;
alter table public.recurring_charges enable row level security;
alter table public.recurring_charge_runs enable row level security;
alter table public.company_settings enable row level security;

drop policy if exists "staff manage quote items" on public.quote_items;
create policy "staff manage quote items" on public.quote_items for all to authenticated
using (public.is_staff()) with check (public.is_staff());
drop policy if exists "staff manage mission adjustments" on public.mission_adjustments;
create policy "staff manage mission adjustments" on public.mission_adjustments for all to authenticated
using (public.is_staff()) with check (public.is_staff());
drop policy if exists "staff read mission events" on public.mission_events;
create policy "staff read mission events" on public.mission_events for select to authenticated using (public.is_staff());
drop policy if exists "staff insert mission events" on public.mission_events;
create policy "staff insert mission events" on public.mission_events for insert to authenticated with check (public.is_staff());
drop policy if exists "finance manage recurring charges" on public.recurring_charges;
create policy "finance manage recurring charges" on public.recurring_charges for all to authenticated
using (public.current_role() in ('admin','comptable')) with check (public.current_role() in ('admin','comptable'));
drop policy if exists "finance read recurring charge runs" on public.recurring_charge_runs;
create policy "finance read recurring charge runs" on public.recurring_charge_runs for select to authenticated
using (public.current_role() in ('admin','comptable'));
drop policy if exists "finance record recurring charge runs" on public.recurring_charge_runs;
create policy "finance record recurring charge runs" on public.recurring_charge_runs for insert to authenticated
with check (public.current_role() in ('admin','comptable'));
drop policy if exists "staff read company settings" on public.company_settings;
create policy "staff read company settings" on public.company_settings for select to authenticated using (public.is_staff());
drop policy if exists "admin update company settings" on public.company_settings;
create policy "admin update company settings" on public.company_settings for update to authenticated
using (public.current_role()='admin') with check (public.current_role()='admin');

grant select,insert,update,delete on public.quote_items, public.mission_adjustments to authenticated;
grant select,insert on public.mission_events to authenticated;
grant select,insert,update,delete on public.recurring_charges, public.company_settings to authenticated;
grant select,insert on public.recurring_charge_runs to authenticated;
grant select on public.mission_financial_summary to authenticated;

drop trigger if exists quote_items_audit on public.quote_items;
create trigger quote_items_audit after insert on public.quote_items for each row execute function public.comtour_audit_event();
drop trigger if exists mission_adjustments_audit on public.mission_adjustments;
create trigger mission_adjustments_audit after insert on public.mission_adjustments for each row execute function public.comtour_audit_event();
drop trigger if exists expenses_mission_event on public.expenses;
create trigger expenses_mission_event after insert on public.expenses for each row execute function public.comtour_audit_event();
drop trigger if exists payments_mission_event on public.payments;
create trigger payments_mission_event after insert on public.payments for each row execute function public.comtour_audit_event();

create or replace function public.recalculate_invoice_status() returns trigger language plpgsql security definer set search_path=public as $$
declare v_invoice uuid; v_total numeric; v_paid numeric;
begin
  if tg_op='DELETE' then v_invoice := old.invoice_id; else v_invoice := new.invoice_id; end if;
  if v_invoice is null then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  select amount*exchange_rate into v_total from public.invoices where id=v_invoice;
  select coalesce(sum(amount*exchange_rate*case when kind='remboursement' then -1 else 1 end),0) into v_paid from public.payments where invoice_id=v_invoice;
  update public.invoices set status=case when v_paid<=0 then 'impayee' when v_paid+0.01>=v_total then 'payee' else 'partiellement_payee' end where id=v_invoice;
  if tg_op='DELETE' then return old; else return new; end if;
end $$;
drop trigger if exists payment_recalculate_invoice on public.payments;
create trigger payment_recalculate_invoice after insert or update or delete on public.payments for each row execute function public.recalculate_invoice_status();

create or replace function public.create_quote_with_items(p_quote jsonb, p_items jsonb)
returns uuid language plpgsql security invoker set search_path=public as $$
declare v_id uuid; v_item jsonb; v_total numeric := 0;
begin
  if not public.is_staff() then raise exception 'Accès non autorisé'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items)=0 then raise exception 'Ajoutez au moins une prestation'; end if;
  insert into public.quotes(reference,title,client_id,status,currency,exchange_rate,deposit_percent,service_clause,amount)
  values(p_quote->>'reference',p_quote->>'title',nullif(p_quote->>'client_id','')::uuid,
    coalesce(p_quote->>'status','brouillon'),coalesce(p_quote->>'currency','KMF'),
    coalesce(nullif(p_quote->>'exchange_rate','')::numeric,1),coalesce(nullif(p_quote->>'deposit_percent','')::numeric,50),
    coalesce(p_quote->>'service_clause',(select service_clause from public.company_settings where id=1)),0)
  returning id into v_id;
  for v_item in select value from jsonb_array_elements(p_items) loop
    insert into public.quote_items(quote_id,service_id,description,quantity,unit,unit_price,service_fee,currency,exchange_rate)
    values(v_id,nullif(v_item->>'service_id','')::uuid,v_item->>'description',coalesce(nullif(v_item->>'quantity','')::numeric,1),
      coalesce(v_item->>'unit','Prestation'),coalesce(nullif(v_item->>'unit_price','')::numeric,0),
      coalesce(nullif(v_item->>'service_fee','')::numeric,0),coalesce(v_item->>'currency',p_quote->>'currency','KMF'),
      coalesce(nullif(v_item->>'exchange_rate','')::numeric,nullif(p_quote->>'exchange_rate','')::numeric,1));
    v_total := v_total + (coalesce(nullif(v_item->>'quantity','')::numeric,1) * coalesce(nullif(v_item->>'unit_price','')::numeric,0)) + coalesce(nullif(v_item->>'service_fee','')::numeric,0);
  end loop;
  update public.quotes set amount=v_total where id=v_id;
  return v_id;
end $$;
grant execute on function public.create_quote_with_items(jsonb,jsonb) to authenticated;

create or replace function public.generate_monthly_charges(p_month date default date_trunc('month',current_date)::date)
returns integer language plpgsql security invoker set search_path=public as $$
declare v_charge public.recurring_charges%rowtype; v_count integer:=0; v_expense uuid; v_date date;
begin
  if public.current_role() not in ('admin','comptable') then raise exception 'Accès comptable requis'; end if;
  for v_charge in select * from public.recurring_charges where active and start_date < (p_month + interval '1 month')::date and (end_date is null or end_date >= p_month) loop
    v_date := make_date(extract(year from p_month)::int,extract(month from p_month)::int,
      least(v_charge.due_day,extract(day from ((p_month + interval '1 month - 1 day')::date))::int));
    if not exists(select 1 from public.recurring_charge_runs where recurring_charge_id=v_charge.id and month=p_month) then
      insert into public.expenses(description,category,amount,currency,exchange_rate,paid_at,supplier_id,payer,is_paid)
      values(v_charge.title,v_charge.category,v_charge.amount,v_charge.currency,v_charge.exchange_rate,v_date,v_charge.supplier_id,'comtour',false)
      returning id into v_expense;
      insert into public.recurring_charge_runs(recurring_charge_id,month,expense_id) values(v_charge.id,p_month,v_expense);
      v_count:=v_count+1;
    end if;
  end loop;
  return v_count;
end $$;
grant execute on function public.generate_monthly_charges(date) to authenticated;

-- Support receipt uploads. The bucket is private; the app uses authenticated signed URLs.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('comtour-documents','comtour-documents',false,10485760,array['application/pdf','image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;
drop policy if exists "staff access own documents" on storage.objects;
create policy "staff access own documents" on storage.objects for all to authenticated
using (bucket_id='comtour-documents' and public.is_staff())
with check (bucket_id='comtour-documents' and public.is_staff());

