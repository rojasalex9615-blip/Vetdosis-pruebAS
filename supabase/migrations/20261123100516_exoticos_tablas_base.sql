-- Modulo de fauna exotica. La unidad es el individuo, no el lote.
-- Convencion del proyecto: authenticated solo lee; toda escritura pasa por
-- RPC SECURITY DEFINER con recibo de idempotencia.

-- 1. Recintos con su rango objetivo.
-- Se guarda el gradiente completo (punto caliente y punto frio) porque en un
-- ectotermo son dos exigencias distintas: una media los oculta a los dos.
create table if not exists public.exotic_enclosures (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  nombre text not null,
  tipo text not null check (tipo in ('terrario','aviario','acuaterrario','acuario','encierro','incubadora')),
  especie text,
  temp_caliente_min numeric(5,2),
  temp_caliente_max numeric(5,2),
  temp_fria_min numeric(5,2),
  temp_fria_max numeric(5,2),
  humedad_min numeric(5,2),
  humedad_max numeric(5,2),
  uv_min numeric(4,2),
  uv_max numeric(4,2),
  ph_min numeric(4,2),
  ph_max numeric(4,2),
  amoniaco_max numeric(6,3),
  nitrito_max numeric(6,3),
  salinidad_min numeric(5,2),
  salinidad_max numeric(5,2),
  activo boolean not null default true,
  notas text,
  version integer not null default 1,
  created_by uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  constraint exotic_enclosures_nombre_unico unique (clinic_id, nombre),
  constraint exotic_enclosures_rango_caliente check (temp_caliente_min is null or temp_caliente_max is null or temp_caliente_min <= temp_caliente_max),
  constraint exotic_enclosures_rango_fria check (temp_fria_min is null or temp_fria_max is null or temp_fria_min <= temp_fria_max),
  constraint exotic_enclosures_rango_humedad check (humedad_min is null or humedad_max is null or humedad_min <= humedad_max),
  constraint exotic_enclosures_rango_uv check (uv_min is null or uv_max is null or uv_min <= uv_max),
  constraint exotic_enclosures_rango_ph check (ph_min is null or ph_max is null or ph_min <= ph_max)
);

-- 2. Lecturas ambientales: lo que el recinto ES, frente a lo que deberia ser.
create table if not exists public.exotic_enclosure_readings (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  enclosure_id uuid not null references public.exotic_enclosures(id) on delete cascade,
  medido_en timestamptz not null default clock_timestamp(),
  temp_caliente numeric(5,2),
  temp_fria numeric(5,2),
  humedad numeric(5,2),
  uv_index numeric(4,2),
  ph numeric(4,2),
  amoniaco numeric(6,3),
  nitrito numeric(6,3),
  salinidad numeric(5,2),
  nota text,
  registrado_por uuid not null,
  created_at timestamptz not null default clock_timestamp()
);
create index if not exists exotic_readings_recinto_idx on public.exotic_enclosure_readings (clinic_id, enclosure_id, medido_en desc);

-- 3. Marcajes. Es lo que permite buscar al ejemplar por microchip o anillo.
create table if not exists public.exotic_identifiers (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  patient_id uuid not null references public.vet_patients(id) on delete cascade,
  tipo text not null check (tipo in ('microchip','anillo','muesca','tatuaje','foto')),
  codigo text not null,
  colocado_el date,
  ubicacion text,
  activo boolean not null default true,
  created_by uuid not null,
  created_at timestamptz not null default clock_timestamp()
);
-- Un codigo activo no puede repetirse dentro de la clinica: si dos ejemplares
-- comparten microchip, el buscador deja de ser fiable.
create unique index if not exists exotic_identifiers_codigo_activo on public.exotic_identifiers (clinic_id, tipo, lower(codigo)) where activo;
create index if not exists exotic_identifiers_paciente_idx on public.exotic_identifiers (clinic_id, patient_id);

-- 4. Estatus legal (CITES / SEMARNAT).
create table if not exists public.exotic_legal_status (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  patient_id uuid not null references public.vet_patients(id) on delete cascade,
  regimen text not null check (regimen in ('cites','semarnat','uma','pimvs','otro')),
  apendice text,
  numero_registro text,
  vigencia_desde date,
  vigencia_hasta date,
  procedencia text,
  documentada boolean not null default false,
  notas text,
  version integer not null default 1,
  created_by uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  constraint exotic_legal_vigencia check (vigencia_desde is null or vigencia_hasta is null or vigencia_desde <= vigencia_hasta)
);
create index if not exists exotic_legal_paciente_idx on public.exotic_legal_status (clinic_id, patient_id);
create index if not exists exotic_legal_vigencia_idx on public.exotic_legal_status (clinic_id, vigencia_hasta);

-- 5. Tomas de alimento y rechazos.
-- En reptiles y aves dejar de comer suele ser el primer signo clinico, asi que
-- el rechazo se registra como dato propio y no como nota suelta.
create table if not exists public.exotic_feedings (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  patient_id uuid not null references public.vet_patients(id) on delete cascade,
  ofrecido_en timestamptz not null default clock_timestamp(),
  alimento text not null,
  aceptado boolean not null,
  cantidad_g numeric(8,2),
  nota text,
  registrado_por uuid not null,
  created_at timestamptz not null default clock_timestamp()
);
create index if not exists exotic_feedings_paciente_idx on public.exotic_feedings (clinic_id, patient_id, ofrecido_en desc);

-- 6. Nidadas e incubacion.
-- La temperatura de incubacion se guarda por puesta porque en varias especies
-- determina el sexo de las crias.
create table if not exists public.exotic_clutches (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  enclosure_id uuid references public.exotic_enclosures(id) on delete set null,
  patient_id uuid references public.vet_patients(id) on delete set null,
  especie text not null,
  puesta_el date not null,
  huevos integer not null check (huevos > 0 and huevos <= 10000),
  fertiles integer check (fertiles is null or fertiles >= 0),
  temp_objetivo numeric(5,2),
  humedad_objetivo numeric(5,2),
  dias_incubacion integer check (dias_incubacion is null or (dias_incubacion > 0 and dias_incubacion <= 400)),
  eclosion_estimada date,
  estado text not null default 'incubando' check (estado in ('incubando','eclosionada','perdida','cancelada')),
  notas text,
  version integer not null default 1,
  created_by uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  constraint exotic_clutches_fertiles check (fertiles is null or fertiles <= huevos)
);
create index if not exists exotic_clutches_estado_idx on public.exotic_clutches (clinic_id, estado, eclosion_estimada);

-- 7. Eventos fisiologicos propios de exoticos (ecdisis, postura, conducta).
create table if not exists public.exotic_events (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  patient_id uuid not null references public.vet_patients(id) on delete cascade,
  tipo text not null check (tipo in ('ecdisis','ecdisis_retenida','postura','vocalizacion','actividad_anormal','enriquecimiento','otro')),
  ocurrio_en timestamptz not null default clock_timestamp(),
  detalle text,
  registrado_por uuid not null,
  created_at timestamptz not null default clock_timestamp()
);
create index if not exists exotic_events_paciente_idx on public.exotic_events (clinic_id, patient_id, ocurrio_en desc);

-- 8. Duracion prevista del aislamiento.
-- hospital_stays sostiene la estancia; aqui solo se anota cuantos dias deberia
-- durar la cuarentena, que es lo que el panel cuenta hacia atras.
create table if not exists public.exotic_quarantine_plans (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  stay_id uuid not null references public.hospital_stays(id) on delete cascade,
  dias integer not null check (dias between 1 and 365),
  motivo text,
  created_by uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  constraint exotic_quarantine_estancia_unica unique (clinic_id, stay_id)
);
