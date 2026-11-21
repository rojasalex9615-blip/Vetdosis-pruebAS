-- CANDIDATO LOCAL. Repara las colisiones de identificadores del catálogo Qwen.
--
-- PROBLEMA. Los lotes se numeraron por separado y al fusionarse chocaron.
--   · Fármacos: 'farmacos_094_101_anestesia' y 'farmacos_094_101_gastro'
--     usan los MISMOS F094..F101 para moléculas distintas (Propofol y
--     Omeprazol comparten F094).
--   · Dosis: 'dosis_103_113_emergencia' y 'dosis_103_114_gastro' comparten
--     D103; 'dosis_103_114_gastro' y 'dosis_114_125_equinos' comparten D114.
--   · Marcas: referencian F094..F101 sin decir de qué lote, así que el cruce
--     es ambiguo.
-- La clave única real era (bloque_origen, id), pero quien cruza por
-- id_farmaco_original —que es lo natural— obtiene dos moléculas a la vez.
-- D152 (Propofol, 4-8 mg/kg IV) y D103 (Omeprazol, 0.5-1 mg/kg PO) caen sobre
-- el mismo F094: un cruce ahí es un error de medicación.
--
-- QUÉ HACE. (1) Renumera el bloque de gastro a F123..F130 y D203..D205, que
-- estaban libres. (2) Añade private.qwen_drug_key / qwen_dose_key como clave
-- estable (bloque + id) para que futuras fusiones no vuelvan a colisionar.
-- (3) Añade índices y restricciones de unicidad global sobre esas claves.
-- (4) Comprueba que no quedan colisiones ni huérfanos y aborta si las hay.
--
-- LO QUE NO HACE. No valida ninguna dosis, no cambia estados de revisión, no
-- copia posología a las tablas de la calculadora y no toca las 1197 pautas.
begin;

-- (1) Mapeo explícito. Se renombra el bloque de GASTRO (no el de anestesia)
-- porque anestesia es el que ya usan las dosis de D152..D159 y las marcas.
create temporary table qwen_farmaco_remap (
  id_viejo text primary key, id_nuevo text not null unique
) on commit drop;
insert into qwen_farmaco_remap (id_viejo, id_nuevo) values
  ('F094','F123'), -- Omeprazol
  ('F095','F124'), -- Ranitidina
  ('F096','F125'), -- Sucralfato
  ('F097','F126'), -- Pimobendan
  ('F098','F127'), -- Enalapril
  ('F099','F128'), -- Digoxina
  ('F100','F129'), -- Clenbuterol
  ('F101','F130'); -- Dobutamina

-- Solo se renombra dentro del bloque de gastro: las mismas claves en el
-- bloque de anestesia siguen siendo válidas.
update private.vetdosis_qwen_farmacos_revision f
   set id_farmaco_original = m.id_nuevo
  from qwen_farmaco_remap m
 where f.bloque_origen = 'farmacos_094_101_gastro'
   and f.id_farmaco_original = m.id_viejo;

update private.vetdosis_qwen_dosis_revision d
   set id_farmaco_original = m.id_nuevo
  from qwen_farmaco_remap m
 where d.bloque_origen = 'dosis_103_114_gastro'
   and d.id_farmaco_original = m.id_viejo;

-- Las marcas del bloque de gastro también, si las hubiera.
update private.vetdosis_qwen_marcas_revision mk
   set id_farmaco_original = m.id_nuevo
  from qwen_farmaco_remap m
 where mk.bloque_origen = 'marcas_qwen_gastro'
   and mk.id_farmaco_original = m.id_viejo;

-- (1b) Dosis duplicadas entre bloques. D103 de gastro pasa a D203 y D114 de
-- gastro a D204; el resto de bloques conserva su numeración.
update private.vetdosis_qwen_dosis_revision
   set id_dosis_original = 'D203'
 where bloque_origen = 'dosis_103_114_gastro' and id_dosis_original = 'D103';
update private.vetdosis_qwen_dosis_revision
   set id_dosis_original = 'D204'
 where bloque_origen = 'dosis_103_114_gastro' and id_dosis_original = 'D114';

-- (2) Claves estables. Evitan que una fusión futura vuelva a colisionar.
alter table private.vetdosis_qwen_farmacos_revision
  add column if not exists clave_global text
    generated always as (bloque_origen || ':' || id_farmaco_original) stored;
alter table private.vetdosis_qwen_dosis_revision
  add column if not exists clave_global text
    generated always as (bloque_origen || ':' || id_dosis_original) stored;

-- (3) Unicidad global del identificador corto: a partir de aquí, un
-- id_farmaco_original no puede designar dos moléculas distintas.
create unique index if not exists vetdosis_qwen_farmacos_id_global_uk
  on private.vetdosis_qwen_farmacos_revision (id_farmaco_original);
create unique index if not exists vetdosis_qwen_dosis_id_global_uk
  on private.vetdosis_qwen_dosis_revision (id_dosis_original);
create index if not exists vetdosis_qwen_dosis_farmaco_ix
  on private.vetdosis_qwen_dosis_revision (id_farmaco_original);
create index if not exists vetdosis_qwen_marcas_farmaco_ix
  on private.vetdosis_qwen_marcas_revision (id_farmaco_original);

-- (4) Verificación. Si algo no cuadra, se revierte todo.
do $verify$
declare
  v_dup_farmaco integer;
  v_dup_dosis integer;
  v_huerfanas integer;
begin
  select count(*) into v_dup_farmaco from (
    select id_farmaco_original from private.vetdosis_qwen_farmacos_revision
     group by 1 having count(*) > 1
  ) z;
  if v_dup_farmaco > 0 then
    raise exception 'Quedan % id_farmaco_original duplicados', v_dup_farmaco;
  end if;

  select count(*) into v_dup_dosis from (
    select id_dosis_original from private.vetdosis_qwen_dosis_revision
     group by 1 having count(*) > 1
  ) z;
  if v_dup_dosis > 0 then
    raise exception 'Quedan % id_dosis_original duplicados', v_dup_dosis;
  end if;

  select count(*) into v_huerfanas
    from private.vetdosis_qwen_dosis_revision d
   where not exists (
     select 1 from private.vetdosis_qwen_farmacos_revision f
      where f.id_farmaco_original = d.id_farmaco_original);
  if v_huerfanas > 0 then
    raise exception 'Quedan % dosis sin fármaco', v_huerfanas;
  end if;
end$verify$;

commit;
