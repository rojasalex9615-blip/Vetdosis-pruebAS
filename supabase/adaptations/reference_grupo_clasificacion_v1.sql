-- Aplicado el 2026-11-26 en wtrelwtztkddfktrfdpb.
-- Grupo de clasificación por nivel de riesgo del ingrediente activo,
-- según el Acuerdo publicado en el DOF el 05/03/2012.
-- El relleno se generó con docs/audits/handoff-extraccion/scripts/grupo_clasificacion.py

alter table private.vetdosis_qwen_farmacos_revision
  add column if not exists grupo_clasificacion text,
  add column if not exists grupo_fuente text,
  add column if not exists grupo_metodo text,
  add column if not exists grupo_actualizado_en date;

alter table private.vetdosis_qwen_farmacos_revision
  drop constraint if exists vetdosis_qwen_farmacos_grupo_chk,
  add constraint vetdosis_qwen_farmacos_grupo_chk
  check (grupo_clasificacion is null or grupo_clasificacion in ('I','II','III'));

alter table private.vetdosis_qwen_dosis_revision
  add column if not exists grupo_clasificacion text;

alter table private.vetdosis_qwen_dosis_revision
  drop constraint if exists vetdosis_qwen_dosis_grupo_chk,
  add constraint vetdosis_qwen_dosis_grupo_chk
  check (grupo_clasificacion is null or grupo_clasificacion in ('I','II','III'));

comment on column private.vetdosis_qwen_farmacos_revision.grupo_clasificacion is
  'Grupo I/II/III del Acuerdo DOF 05/03/2012 por nivel de riesgo del ingrediente activo. Null = no figura en el listado; no implica otro grupo.';
comment on column private.vetdosis_qwen_farmacos_revision.grupo_fuente is
  'Documento del que sale la clasificación.';
comment on column private.vetdosis_qwen_farmacos_revision.grupo_metodo is
  'exacto = nombre idéntico en el acuerdo; variante = solo cambia la grafía o la sal.';
comment on column private.vetdosis_qwen_farmacos_revision.grupo_actualizado_en is
  'Fecha de la última carga de la clasificación.';
comment on column private.vetdosis_qwen_dosis_revision.grupo_clasificacion is
  'Derivado del principio activo. Se mantiene por comodidad de consulta; el origen es vetdosis_qwen_farmacos_revision.';
