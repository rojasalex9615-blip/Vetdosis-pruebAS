-- Gestacion: una sola tabla para toda la app.
--
-- Cuelga de vet_patients, no de un modulo. La razon es estructural: una
-- gestacion es un hecho de una hembra concreta, y produccion no tiene animales
-- individuales (lotes_produccion cuenta `cabezas`, que es un numero). El
-- precedente ya estaba puesto por exotic_clutches, que cuelga de vet_patients
-- con un vinculo opcional al sitio; esta es su gemela vivipara.
--
-- `lote_id` es opcional y es lo unico especifico de produccion: dice a que
-- lote pertenece la hembra, para poder sumar partos por lote sin duplicar la
-- tabla.

create table if not exists public.reproduccion_gestaciones (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  patient_id uuid not null references public.vet_patients(id) on delete cascade,
  lote_id uuid references public.lotes_produccion(id) on delete set null,
  especie text not null,
  servicio_el date not null,
  metodo text not null default 'monta_natural'
    check (metodo in ('monta_natural','inseminacion_artificial','transferencia_embrion','desconocido')),
  semental text check (semental is null or (char_length(btrim(semental)) between 1 and 80)),
  dias_gestacion integer check (dias_gestacion is null or (dias_gestacion between 1 and 400)),
  parto_estimado date,
  diagnostico text not null default 'pendiente'
    check (diagnostico in ('pendiente','gestante','vacia','dudosa')),
  diagnostico_el date,
  parto_el date,
  crias_vivas integer check (crias_vivas is null or (crias_vivas between 0 and 10000)),
  crias_muertas integer check (crias_muertas is null or (crias_muertas between 0 and 10000)),
  estado text not null default 'en_curso'
    check (estado in ('en_curso','parida','aborto','vacia','cancelada')),
  notas text check (notas is null or char_length(notas) <= 2000),
  version integer not null default 1 check (version > 0),
  created_by uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  constraint reproduccion_gestaciones_parto_orden
    check (parto_el is null or parto_el >= servicio_el),
  constraint reproduccion_gestaciones_diagnostico_orden
    check (diagnostico_el is null or diagnostico_el >= servicio_el),
  -- Si ya pario, la fecha del parto no puede faltar: un estado que afirma algo
  -- sin el dato que lo sostiene es justo lo que no queremos guardar.
  constraint reproduccion_gestaciones_parida_con_fecha
    check (estado <> 'parida' or parto_el is not null)
);

-- Las dos consultas que de verdad se hacen: "que hembras me paren pronto" y
-- "el historial de esta hembra".
create index if not exists reproduccion_gestaciones_pendientes_idx
  on public.reproduccion_gestaciones (clinic_id, estado, parto_estimado);
create index if not exists reproduccion_gestaciones_paciente_idx
  on public.reproduccion_gestaciones (clinic_id, patient_id, servicio_el desc);
create index if not exists reproduccion_gestaciones_lote_idx
  on public.reproduccion_gestaciones (clinic_id, lote_id)
  where lote_id is not null;

-- Catalogo de dias de gestacion por especie.
--
-- A diferencia de produccion_metricas, este catalogo SUGIERE, no obliga. El
-- motivo es que los dos modulos hablan vocabularios distintos: produccion usa
-- codigos cerrados (`bovino`, `cerdo`) y vet_patients.species es texto libre
-- escrito por quien da de alta al paciente. Si el servidor exigiera que la
-- especie estuviera en el catalogo, no se podria registrar la gestacion de
-- nada que no hubieramos previsto, que es lo contrario de lo que hace falta.
create table if not exists public.reproduccion_gestacion_dias (
  especie text primary key,
  nombre text not null,
  grupo text not null,
  dias_min integer not null check (dias_min between 1 and 400),
  dias_prom integer not null check (dias_prom between 1 and 400),
  dias_max integer not null check (dias_max between 1 and 400),
  activo boolean not null default true,
  constraint reproduccion_gestacion_dias_orden
    check (dias_min <= dias_prom and dias_prom <= dias_max)
);

comment on table public.reproduccion_gestaciones is
  'Gestacion individual. Compartida por produccion y exoticos; cuelga del paciente.';
comment on column public.reproduccion_gestaciones.parto_estimado is
  'Derivado en el servidor como servicio_el + dias_gestacion, para no depender del reloj del movil.';
comment on table public.reproduccion_gestacion_dias is
  'Catalogo de referencia. Sugiere los dias de gestacion; no restringe que especies se pueden registrar.';
