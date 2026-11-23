-- Inventario de alimento: catalogo, silos y libro de movimientos.
-- El alimento no cabe en public.inventario porque esa tabla es un punto de venta
-- (precio_venta not null, user_id not null, movimientos kind in venta/frasco/reverso
-- y lot_id not null). Aqui el consumidor no es un cliente sino un lote de produccion.

create table if not exists public.produccion_alimentos (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  nombre text not null check (char_length(btrim(nombre)) between 1 and 120),
  tipo text not null default 'concentrado' check (tipo in ('concentrado','forraje','ensilado','mineral','aditivo','leche','medicado','otro')),
  unidad text not null default 'kg' check (unidad in ('kg','ton','saco','costal','paca','l')),
  kg_por_unidad numeric not null default 1 check (kg_por_unidad > 0 and kg_por_unidad <= 100000),
  materia_seca_pct numeric check (materia_seca_pct is null or (materia_seca_pct > 0 and materia_seca_pct <= 100)),
  proteina_pct numeric check (proteina_pct is null or (proteina_pct >= 0 and proteina_pct <= 100)),
  activo boolean not null default true,
  notas text not null default '' check (char_length(notas) <= 2000),
  version integer not null default 1 check (version > 0),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (id, clinic_id)
);

create unique index if not exists produccion_alimentos_nombre_unico
  on public.produccion_alimentos (clinic_id, lower(btrim(nombre)));
create index if not exists produccion_alimentos_clinic_activo
  on public.produccion_alimentos (clinic_id, activo, lower(btrim(nombre)));

create table if not exists public.produccion_silos (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  nombre text not null check (char_length(btrim(nombre)) between 1 and 80),
  tipo text not null default 'silo' check (tipo in ('silo','bodega','tolva','trinchera','otro')),
  capacidad_kg numeric check (capacidad_kg is null or (capacidad_kg > 0 and capacidad_kg <= 100000000)),
  alimento_id uuid references public.produccion_alimentos(id) on delete set null,
  activo boolean not null default true,
  notas text not null default '' check (char_length(notas) <= 2000),
  version integer not null default 1 check (version > 0),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (id, clinic_id)
);

create unique index if not exists produccion_silos_nombre_unico
  on public.produccion_silos (clinic_id, lower(btrim(nombre)));
create index if not exists produccion_silos_clinic_activo
  on public.produccion_silos (clinic_id, activo, lower(btrim(nombre)));

-- Libro de movimientos. Todo se guarda en kilogramos: la unidad de compra
-- (saco, paca, tonelada) se convierte en el formulario y se ve antes de guardar,
-- asi un cambio posterior de kg_por_unidad no reescribe la historia.
-- kg es un delta con signo: compra suma, consumo y merma restan, ajuste cualquiera.
create table if not exists public.produccion_alimento_movimientos (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  alimento_id uuid not null,
  silo_id uuid,
  lote_id uuid,
  fecha date not null default current_date,
  tipo text not null check (tipo in ('compra','consumo','merma','ajuste')),
  kg numeric not null check (kg <> 0 and abs(kg) <= 10000000),
  costo_kg numeric not null default 0 check (costo_kg >= 0 and costo_kg <= 1000000),
  proveedor text not null default '' check (char_length(proveedor) <= 120),
  referencia text not null default '' check (char_length(referencia) <= 60),
  nota text not null default '' check (char_length(nota) <= 2000),
  registrado_por uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  foreign key (alimento_id, clinic_id) references public.produccion_alimentos(id, clinic_id) on delete cascade,
  foreign key (silo_id, clinic_id) references public.produccion_silos(id, clinic_id),
  foreign key (lote_id, clinic_id) references public.lotes_produccion(id, clinic_id),
  constraint produccion_alimento_mov_compra_suma check (tipo <> 'compra' or kg > 0),
  constraint produccion_alimento_mov_salida_resta check (tipo not in ('consumo','merma') or kg < 0),
  constraint produccion_alimento_mov_consumo_con_lote check (tipo <> 'consumo' or lote_id is not null)
);

create index if not exists produccion_alimento_mov_alimento
  on public.produccion_alimento_movimientos (clinic_id, alimento_id, fecha desc);
create index if not exists produccion_alimento_mov_lote
  on public.produccion_alimento_movimientos (clinic_id, lote_id, fecha desc) where lote_id is not null;
create index if not exists produccion_alimento_mov_silo
  on public.produccion_alimento_movimientos (clinic_id, silo_id, fecha desc) where silo_id is not null;
create index if not exists produccion_alimento_mov_tipo
  on public.produccion_alimento_movimientos (clinic_id, tipo, fecha desc);

alter table public.produccion_alimentos enable row level security;
alter table public.produccion_silos enable row level security;
alter table public.produccion_alimento_movimientos enable row level security;

-- Toda tabla nueva nace con insert/update/delete/truncate para authenticated y anon.
-- RLS no frena TRUNCATE, asi que el revoke va aqui mismo y no en otra migracion.
revoke all on public.produccion_alimentos, public.produccion_silos, public.produccion_alimento_movimientos from public, anon, authenticated;
grant select on public.produccion_alimentos, public.produccion_silos, public.produccion_alimento_movimientos to authenticated;

drop policy if exists produccion_alimentos_read on public.produccion_alimentos;
create policy produccion_alimentos_read on public.produccion_alimentos for select to authenticated using (private.has_clinic_role(clinic_id));
drop policy if exists produccion_silos_read on public.produccion_silos;
create policy produccion_silos_read on public.produccion_silos for select to authenticated using (private.has_clinic_role(clinic_id));
drop policy if exists produccion_alimento_mov_read on public.produccion_alimento_movimientos;
create policy produccion_alimento_mov_read on public.produccion_alimento_movimientos for select to authenticated using (private.has_clinic_role(clinic_id));

notify pgrst,'reload schema';
