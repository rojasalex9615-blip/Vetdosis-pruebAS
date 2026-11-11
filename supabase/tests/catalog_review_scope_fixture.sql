-- Synthetic catalog and identities for the local scope-isolation contract only.
-- Never apply this fixture to a Supabase project.
create schema if not exists private;

insert into auth.users(id, email, email_confirmed_at)
values
  ('ae270fa9-5d73-4ca4-b2ab-35d46d30c28a'::uuid, 'catalog-actor@example.invalid', now()),
  ('f13a9b24-5c7d-4e61-9b31-2a4d8e6f701c'::uuid, 'catalog-owner@example.invalid', now())
on conflict (id) do nothing;

insert into public.clinics(id, name, created_by)
values
  ('2d61242b-d2aa-4624-8c7d-6cf420aad49c'::uuid, 'Catálogo scope actor', 'ae270fa9-5d73-4ca4-b2ab-35d46d30c28a'::uuid),
  ('e68a35d4-82ef-4a9a-819b-05c23df64bba'::uuid, 'Catálogo scope owner', 'f13a9b24-5c7d-4e61-9b31-2a4d8e6f701c'::uuid)
on conflict (id) do nothing;

insert into public.clinic_members(clinic_id, user_id, role)
values
  ('2d61242b-d2aa-4624-8c7d-6cf420aad49c'::uuid, 'ae270fa9-5d73-4ca4-b2ab-35d46d30c28a'::uuid, 'admin'),
  ('e68a35d4-82ef-4a9a-819b-05c23df64bba'::uuid, 'f13a9b24-5c7d-4e61-9b31-2a4d8e6f701c'::uuid, 'admin')
on conflict (clinic_id, user_id) do nothing;

create table if not exists private.vetdosis_catalogos_laboratorios_revision (
  id bigint primary key,
  estado_revision text not null default 'sin_verificar'
    check (estado_revision in ('sin_verificar','revisar_conflicto','validado','descartado')),
  documento_origen text,
  nombre_comercial text not null,
  laboratorio text not null,
  principios_activos text,
  concentracion text,
  presentacion text,
  especies text,
  via_administracion text,
  dosis_catalogo_texto text,
  indicaciones text,
  pagina_origen integer,
  habilitado_en_app boolean,
  registro text,
  jurisdiccion_registro text,
  alerta_formato text
);
create table if not exists private.vetdosis_mederilab_catalogo_revision
  (like private.vetdosis_catalogos_laboratorios_revision including all);
create table if not exists private.vetdosis_zoetis_holland_catalogo_revision
  (like private.vetdosis_catalogos_laboratorios_revision including all);
create table if not exists private.vetdosis_virbac_productos (
  id text primary key,
  estado text not null default 'sin verificar'
    check (estado in ('sin verificar','revisar_conflicto','validado','descartado')),
  documento_origen text,
  nombre_comercial text not null,
  laboratorio text not null,
  principios_activos text,
  concentracion text,
  presentacion text,
  especies text,
  via_administracion text,
  dosis_catalogo_texto text,
  indicaciones text,
  pagina_origen integer,
  habilitado_en_app boolean,
  registro text,
  jurisdiccion_registro text,
  alerta_formato text
);

insert into private.vetdosis_catalogos_laboratorios_revision(
  id, estado_revision, documento_origen, nombre_comercial, laboratorio,
  principios_activos, concentracion, presentacion, especies,
  via_administracion, dosis_catalogo_texto, indicaciones, pagina_origen,
  habilitado_en_app, registro, jurisdiccion_registro, alerta_formato
) values (
  1, 'sin_verificar', 'catalog-review-test-v1', 'Producto ficticio',
  'Laboratorio de prueba', 'Ingrediente de prueba', '10 mg/ml',
  'Frasco de prueba', 'Canino', 'Oral', 'No es una pauta clínica',
  'Solo fixture', 1, false, null, 'MX', null
) on conflict (id) do nothing;

insert into private.vetdosis_virbac_productos(
  id, estado, documento_origen, nombre_comercial, laboratorio, especies,
  presentacion, habilitado_en_app, registro, jurisdiccion_registro
) values (
  'virbac-test-1', 'sin verificar', 'catalog-review-test-v1',
  'Producto Virbac ficticio', 'Laboratorio Virbac de prueba', 'Canino',
  'Frasco de prueba', false, null, 'MX'
) on conflict (id) do nothing;

create or replace view private.vetdosis_inventario_comercial_revision as
select 'grok_catalogos'::text as fuente_sistema, id::text as id_fuente,
  documento_origen, nombre_comercial, laboratorio, principios_activos,
  concentracion, presentacion, especies, via_administracion,
  dosis_catalogo_texto, indicaciones, pagina_origen, habilitado_en_app,
  registro, jurisdiccion_registro, alerta_formato, estado_revision
from private.vetdosis_catalogos_laboratorios_revision
union all
select 'grok_mederilab', id::text, documento_origen, nombre_comercial,
  laboratorio, principios_activos, concentracion, presentacion, especies,
  via_administracion, dosis_catalogo_texto, indicaciones, pagina_origen,
  habilitado_en_app, registro, jurisdiccion_registro, alerta_formato,
  estado_revision
from private.vetdosis_mederilab_catalogo_revision
union all
select 'grok_zoetis_holland', id::text, documento_origen, nombre_comercial,
  laboratorio, principios_activos, concentracion, presentacion, especies,
  via_administracion, dosis_catalogo_texto, indicaciones, pagina_origen,
  habilitado_en_app, registro, jurisdiccion_registro, alerta_formato,
  estado_revision
from private.vetdosis_zoetis_holland_catalogo_revision
union all
select 'claude_virbac', id, documento_origen, nombre_comercial, laboratorio,
  principios_activos, concentracion, presentacion, especies,
  via_administracion, dosis_catalogo_texto, indicaciones, pagina_origen,
  habilitado_en_app, registro, jurisdiccion_registro, alerta_formato,
  case when estado = 'sin verificar' then 'sin_verificar' else estado end
from private.vetdosis_virbac_productos;

create table if not exists public.catalog_review_reports (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  source_catalog text not null,
  source_key text not null,
  module text not null,
  reviewer_id uuid not null references auth.users(id),
  catalog_version text not null,
  observed_snapshot jsonb not null,
  expected_value text,
  source_reference text,
  comment text not null,
  created_at timestamptz not null default now()
);
