-- Existencias y eficiencia. Son vistas y no calculo en el telefono porque una
-- granja genera miles de movimientos al ano: traerlos todos para sumarlos se
-- rompe el primer ano. security_invoker deja que mande el RLS de las tablas base.

create or replace view public.produccion_alimento_existencias
with (security_invoker = on) as
select
  m.clinic_id,
  m.alimento_id,
  m.silo_id,
  sum(m.kg) as kg,
  sum(m.kg * m.costo_kg) as valor,
  sum(case when m.tipo in ('consumo','merma') and m.fecha >= current_date - 29 then -m.kg else 0 end) as kg_salida_30d,
  min(case when m.tipo in ('consumo','merma') and m.fecha >= current_date - 29 then m.fecha end) as primera_salida_30d,
  max(m.fecha) as ultimo_movimiento
from public.produccion_alimento_movimientos m
group by m.clinic_id, m.alimento_id, m.silo_id;

-- Un lote con su alimento y su produccion, que es lo que vuelve ciertas la
-- conversion alimenticia y el costo por litro o por kilo.
create or replace view public.produccion_lote_eficiencia
with (security_invoker = on) as
select
  l.clinic_id,
  l.id as lote_id,
  l.codigo,
  l.nombre,
  l.especie,
  l.proposito,
  l.cabezas,
  l.estado,
  coalesce(a.kg_alimento, 0) as kg_alimento,
  a.kg_materia_seca,
  coalesce(a.costo_alimento, 0) as costo_alimento,
  a.primera_carga,
  a.ultima_carga,
  coalesce(r.leche_l, 0) as leche_l,
  coalesce(r.huevos, 0) as huevos,
  coalesce(r.miel_kg, 0) as miel_kg,
  coalesce(r.dias_con_registro, 0) as dias_con_registro,
  p.peso_inicial_kg,
  p.peso_final_kg
from public.lotes_produccion l
left join lateral (
  select
    sum(-m.kg) as kg_alimento,
    case when bool_or(f.materia_seca_pct is null) then null
         else sum(-m.kg * f.materia_seca_pct / 100.0) end as kg_materia_seca,
    sum(-m.kg * m.costo_kg) as costo_alimento,
    min(m.fecha) as primera_carga,
    max(m.fecha) as ultima_carga
  from public.produccion_alimento_movimientos m
  join public.produccion_alimentos f on f.id = m.alimento_id and f.clinic_id = m.clinic_id
  where m.lote_id = l.id and m.clinic_id = l.clinic_id and m.tipo = 'consumo'
) a on true
left join lateral (
  select
    sum(coalesce((rg.metricas->>'leche_litros')::numeric, 0)) as leche_l,
    sum(coalesce((rg.metricas->>'huevos_total')::numeric, 0)) as huevos,
    sum(coalesce((rg.metricas->>'miel_kg')::numeric, 0)) as miel_kg,
    count(*) as dias_con_registro
  from public.produccion_registros rg
  where rg.lote_id = l.id and rg.clinic_id = l.clinic_id
) r on true
left join lateral (
  select
    (select (x.metricas->>'peso_total_kg')::numeric from public.produccion_registros x
      where x.lote_id = l.id and x.clinic_id = l.clinic_id and jsonb_exists(x.metricas, 'peso_total_kg')
      order by x.fecha asc limit 1) as peso_inicial_kg,
    (select (y.metricas->>'peso_total_kg')::numeric from public.produccion_registros y
      where y.lote_id = l.id and y.clinic_id = l.clinic_id and jsonb_exists(y.metricas, 'peso_total_kg')
      order by y.fecha desc limit 1) as peso_final_kg
) p on true;

revoke all on public.produccion_alimento_existencias, public.produccion_lote_eficiencia from public, anon, authenticated;
grant select on public.produccion_alimento_existencias, public.produccion_lote_eficiencia to authenticated;

notify pgrst,'reload schema';
