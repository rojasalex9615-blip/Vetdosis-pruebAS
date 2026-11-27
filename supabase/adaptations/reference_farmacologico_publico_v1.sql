-- Aplicado el 2026-11-26 en wtrelwtztkddfktrfdpb.
-- Expone el vademécum farmacológico en lectura para la app.
--
-- Las tablas siguen en el esquema private, con RLS y sin políticas: solo el
-- dueño las ve. Lo que se publica son dos vistas de solo lectura y una fila de
-- versión. La clave publicable de la app no puede leer las tablas originales.

create or replace view public.vetdosis_farmacologico_principios as
select id_farmaco_original as id,
       principio_activo,
       sinonimos,
       grupo_clasificacion,
       grupo_fuente
  from private.vetdosis_qwen_farmacos_revision;

create or replace view public.vetdosis_farmacologico_pautas as
select id_dosis_original as id,
       id_farmaco_original as id_farmaco,
       bloque_origen,
       especie,
       especies,
       indicacion,
       dosis_original,
       unidad_original,
       dosis_min,
       dosis_max,
       via,
       intervalo,
       duracion,
       condiciones_contraindicaciones,
       autor,
       titulo,
       edicion,
       anio,
       edicion_pagina,
       seccion,
       regla,
       base_calculo,
       estado_normalizacion,
       motivo_no_normalizado,
       grupo_clasificacion
  from private.vetdosis_qwen_dosis_revision;

grant select on public.vetdosis_farmacologico_principios to anon, authenticated;
grant select on public.vetdosis_farmacologico_pautas to anon, authenticated;

create table if not exists public.vetdosis_farmacologico_version (
  id int primary key check (id = 1),
  version text not null,
  principios int not null,
  pautas int not null,
  calculables int not null,
  actualizado_en timestamptz not null default now()
);

alter table public.vetdosis_farmacologico_version enable row level security;

drop policy if exists lectura_publica on public.vetdosis_farmacologico_version;
create policy lectura_publica on public.vetdosis_farmacologico_version
  for select to anon, authenticated using (true);

grant select on public.vetdosis_farmacologico_version to anon, authenticated;

insert into public.vetdosis_farmacologico_version (id, version, principios, pautas, calculables)
select 1, 'v1', count(distinct id_farmaco_original), count(*),
       count(*) filter (where dosis_min is not null and base_calculo is not null)
  from private.vetdosis_qwen_dosis_revision
on conflict (id) do update
   set version = excluded.version, principios = excluded.principios,
       pautas = excluded.pautas, calculables = excluded.calculables,
       actualizado_en = now();
