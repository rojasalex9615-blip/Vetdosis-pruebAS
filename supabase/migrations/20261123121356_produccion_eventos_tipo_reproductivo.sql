-- La otra mitad de la reproduccion: la que NO es individual.
--
-- Nadie abre una ficha por cada una de 550 cerdas. Para el lote hace falta
-- poder anotar "esta banda tuvo 44 partos", y eso es un evento del lote, no
-- una gestacion. Cabe en produccion_eventos; solo faltaba el tipo.
--
-- OJO: la reescritura del RPC que iba en esta migracion tenia errores y quedo
-- corregida en 20261123121433. Lo que vale es aquella.

alter table public.produccion_eventos
  drop constraint if exists produccion_eventos_tipo_check;

alter table public.produccion_eventos
  add constraint produccion_eventos_tipo_check
  check (tipo in ('sanitario','mortalidad','pesaje','traslado','sacrificio','reproductivo','otro'));
