-- ============================================================
-- PLANTEC CRM — Schema Supabase
-- Execute este script no SQL Editor do Supabase
-- ============================================================

-- 1. PROFILES (consultores e gestores)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  full_name text,
  role text not null default 'consultor' check (role in ('consultor','gestor')),
  active boolean default true,
  created_at timestamptz default now()
);

-- 2. CLIENTS
create table public.clients (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  cnpj text,
  site text,
  segment text,
  origem text,
  contact text,
  cargo text,
  phone text,
  cod_gestao text,
  status text default 'prospecto' check (status in ('prospecto','carteira','inativo')),
  temp text default '' check (temp in ('','frio','morno','quente')),
  is_new_lead boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 3. TASKS
create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  text text not null,
  priority text default '' check (priority in ('','alta','media','baixa')),
  due date,
  done boolean default false,
  done_at timestamptz,
  is_checklist boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 4. NOTES (linha do tempo)
create table public.notes (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  text text not null,
  created_at timestamptz default now()
);

-- 5. PRODUTOS MONITORAMENTO
create table public.produtos_monitoramento (
  id uuid primary key default gen_random_uuid(),
  codigo text,
  descricao text not null,
  segmento text,
  updated_at timestamptz default now()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles enable row level security;
alter table public.clients enable row level security;
alter table public.tasks enable row level security;
alter table public.notes enable row level security;
alter table public.produtos_monitoramento enable row level security;

-- PROFILES
create policy "usuarios veem proprio perfil" on public.profiles
  for select using (auth.uid() = id);

create policy "gestores veem todos perfis" on public.profiles
  for select using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'gestor')
  );

create policy "gestores inserem perfis" on public.profiles
  for insert with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'gestor')
  );

create policy "gestores atualizam perfis" on public.profiles
  for update using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'gestor')
  );

-- CLIENTS: consultor vê só os seus; gestor vê todos
create policy "consultor vê seus clientes" on public.clients
  for select using (
    user_id = auth.uid() or
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'gestor')
  );
create policy "consultor insere clientes" on public.clients
  for insert with check (
    user_id = auth.uid() or
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'gestor')
  );
create policy "consultor atualiza clientes" on public.clients
  for update using (
    user_id = auth.uid() or
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'gestor')
  );
create policy "consultor deleta clientes" on public.clients
  for delete using (
    user_id = auth.uid() or
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'gestor')
  );

-- TASKS
create policy "acesso tasks" on public.tasks
  for all using (
    user_id = auth.uid() or
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'gestor')
  );

-- NOTES
create policy "acesso notes" on public.notes
  for all using (
    user_id = auth.uid() or
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'gestor')
  );

-- PRODUTOS: todos leem; só gestor escreve
create policy "todos leem produtos" on public.produtos_monitoramento
  for select using (true);

create policy "gestor gerencia produtos" on public.produtos_monitoramento
  for all using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'gestor')
  );

-- ============================================================
-- FUNÇÃO: criar profile após signup
-- ============================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, username, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email,'@',1)),
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'role', 'consultor')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- PRODUTOS DEFAULT (lista inicial)
-- ============================================================
insert into public.produtos_monitoramento (codigo, descricao, segmento) values
('4543590','AMT 8000 LITE (Central de alarme sem fio com sirene inclusa)','Alarmes'),
('4540055','Central de Alarme AMT 1000 Smart','Alarmes'),
('4543578','Central de Alarme AMT 2018 E Smart','Alarmes'),
('4543510','FXO 8000','Alarmes'),
('4543513','XAC 8000','Alarmes'),
('4543515','XAT 8000','Alarmes'),
('4543519','PGM 8000','Alarmes'),
('4543537','REP 8000','Alarmes'),
('4543516','AMT 8000','Alarmes'),
('4543511','XAG 8000','Alarmes'),
('4543514','XSS 8000','Alarmes'),
('4543565','XAG 8000 3G','Alarmes'),
('4543589','AMT 8000 PRO','Alarmes'),
('4543582','XG 2G','Alarmes'),
('4543583','XG 3G','Alarmes'),
('4543584','XG 4G','Alarmes'),
('4541034','IVP 8000 PET','Sensores'),
('4541035','IVP 8000 PET CAM','Sensores'),
('4541041','IVP 8000 EX','Sensores'),
('4541032','XAS 8000','Sensores'),
('4541033','TX 8000','Sensores'),
('4910011','Maleta Sistema 8000','Sensores'),
('4541071','IVP 1000 PET','Sensores'),
('4541073','IVP 1000 PET Smart','Sensores'),
('4540039','Conjunto IVP 1000 PET Smart','Sensores'),
('4540029','Conjunto IVP 1000 PET','Sensores'),
('4541052','XAS Smart','Sensores'),
('4541042','XAS Smart Black','Sensores'),
('4541024','TX 4020 Smart','Sensores'),
('4540053','IVP 7000 MW EX','Sensores'),
('4541076','IVP 7000 EX','Sensores'),
('4540015','IVP 9000 MW','Sensores'),
('4541064','IVP 9000 MW MASK','Sensores'),
('4541054','IVA 9100 TRI','Sensores'),
('4540089','IVP 5000 LD','Sensores'),
('4540083','IVP 5000 SMART LD','Sensores'),
('4540088','IVP 5000 MW LD','Sensores'),
('4540082','IVP 7000 MW MASK LD','Sensores'),
('4540105','IVP 8000 LD','Sensores'),
('4540094','IVA 8040 AT','Sensores'),
('4540111','IVP 8000 MW PET','Sensores'),
('4540056','IVP 8000 PET G2','Sensores'),
('4570059','Câmera IP Wi-Fi VIPW 1210 C','CFTV IP'),
('4570057','Câmera IP Wi-Fi VIPW 1410 MINI','CFTV IP'),
('4860010','Bateria VRLA PB 12V 4,5AH XB 12SEG','Energia'),
('4821000','Bateria VRLA PB 12V 7AH XB 1270','Energia');
