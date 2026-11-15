-- 15R: catalogo UPP de ejemplo (fases, supuestos y avisos de datos faltantes).
-- Origen: UPP_ejemplo_tablas_base.xlsx (Rancho La Huamuchilera, proyecto 2022).
-- Catalogo de solo lectura para autenticados; mismas reglas que
-- produccion_especies/produccion_metricas de 20261112000100_produccion_lotes.sql.
--
-- ESTADO: CANDIDATO. No aplicado en Supabase Pruebas. Los datos del proyecto
-- 2022 son ilustrativos y sin confirmar con el productor.
begin;

create table if not exists public.produccion_upp_fases (
  id text primary key check (id ~ '^[a-z][a-z0-9_]{2,59}$'),
  fase text not null check (char_length(btrim(fase)) between 3 and 80),
  peso_entrada_kg numeric not null check (peso_entrada_kg >= 0),
  peso_salida_kg numeric not null check (peso_salida_kg >= 0),
  dias integer not null check (dias between 1 and 3650),
  consumo_kg_dia numeric not null check (consumo_kg_dia >= 0),
  agua_l_dia numeric not null check (agua_l_dia >= 0),
  espacio_m2 numeric not null check (espacio_m2 >= 0),
  temp_c numeric not null,
  proteina_cruda_pct numeric not null check (proteina_cruda_pct between 0 and 100),
  fosforo_pct numeric not null check (fosforo_pct between 0 and 100),
  excreta_pct_peso_vivo numeric not null check (excreta_pct_peso_vivo >= 0),
  precio_alimento_mxn_kg numeric not null check (precio_alimento_mxn_kg >= 0),
  gdp_kg_dia numeric not null,
  gdp_retencion_kg_dia numeric,
  origen text not null default '' check (char_length(origen) <= 400),
  orden integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists produccion_upp_fases_orden on public.produccion_upp_fases(orden, fase);

alter table public.produccion_upp_fases enable row level security;
revoke all on public.produccion_upp_fases from public,anon,authenticated;
grant select on public.produccion_upp_fases to authenticated;

drop policy if exists produccion_upp_fases_read on public.produccion_upp_fases;
create policy produccion_upp_fases_read on public.produccion_upp_fases
  for select to authenticated using (auth.uid() is not null);

insert into public.produccion_upp_fases(id,fase,peso_entrada_kg,peso_salida_kg,dias,consumo_kg_dia,agua_l_dia,espacio_m2,temp_c,proteina_cruda_pct,fosforo_pct,excreta_pct_peso_vivo,precio_alimento_mxn_kg,gdp_kg_dia,gdp_retencion_kg_dia,origen,orden) values
 ('gestacion','Gestación (cerda)',200,240,114,2,15,4,18,13.5,0.55,2.7,7.5,0.350877192982456,null,'UPP: consumo 2 kg/dia; corral individual 2x2 m. Resto referencia.',1),
 ('lactancia','Lactancia (cerda)',240,225,20,3.5,25,4,22,17.5,0.65,6,9.5,-0.75,2.25,'UPP: lactancia 20 d, consumo 3-4 kg/dia (3.5). Retiene la camada.',2),
 ('lechon_predestete','Lechón predestete',1.5,6,20,0.05,0.3,0,30,20,0.7,10,18,0.225,null,'UPP: destete 5-7 kg a 25-30 d (se usa 6 kg a 20 d).',3),
 ('destete','Destete / Posdestete',6,20,35,0.6,1.5,0.15,26,19,0.65,10.6,13,0.4,null,'Referencia. UPP vende a los 30-35 d; inventario 0.',4),
 ('desarrollo','Desarrollo / Crecimiento',20,55,50,1.95,4.5,1,20,16.5,0.55,6.3,8.5,0.7,null,'UPP: GDP 695 g/d y CA 3.0 entre 20 y 90 kg.',5),
 ('finalizacion','Finalización / Engorde',55,90,50,2.25,7,1,20,14.5,0.45,6.3,7.5,0.7,null,'UPP: venta a 90 kg (canal 75 %).',6),
 ('sementales','Sementales',200,200,365,2.5,12,1.2,18,13.5,0.55,2.7,7.5,0,null,'UPP: 20 machos en 2 corrales de 3x4 m (1.2 m2).',7)
on conflict (id) do nothing;

create table if not exists public.produccion_upp_avisos (
  id text primary key check (id ~ '^[a-z][a-z0-9_]{2,59}$'),
  tipo text not null check (tipo in ('dato_faltante','inconsistencia','norma','mitigacion')),
  tema text not null check (char_length(btrim(tema)) between 3 and 120),
  detalle text not null check (char_length(btrim(detalle)) between 3 and 600),
  donde_conseguirlo text not null default '' check (char_length(donde_conseguirlo) <= 300),
  orden integer not null default 0
);

alter table public.produccion_upp_avisos enable row level security;
revoke all on public.produccion_upp_avisos from public,anon,authenticated;
grant select on public.produccion_upp_avisos to authenticated;

drop policy if exists produccion_upp_avisos_read on public.produccion_upp_avisos;
create policy produccion_upp_avisos_read on public.produccion_upp_avisos
  for select to authenticated using (auth.uid() is not null);

insert into public.produccion_upp_avisos(id,tipo,tema,detalle,donde_conseguirlo,orden) values
 ('falta_dieta','dato_faltante','Composición de la mezcla de granos (PC %, P %)','Es el dato que más cambia el balance de N y P.','Productor; tablas FEDNA para cada grano',1),
 ('falta_hembras','dato_faltante','Reparto real de hembras (gestantes/lactantes/vacías)','Afecta el inventario del lote.','Registros de servicios y partos',2),
 ('falta_engorda','dato_faltante','Reparto de la engorda (desarrollo vs finalización)','Afecta el inventario del lote.','Tablas por corral del productor',3),
 ('falta_agua','dato_faltante','Consumo y fuente de agua; litros de lavado','Afecta el efluente y la huella.','Medidor o estimación en visita',4),
 ('falta_pastos','dato_faltante','Hectáreas de pasto y manejo del estiércol','Comparar con la superficie necesaria.','Productor',5),
 ('inconsistencia_inventario','inconsistencia','100 hembras pero 10 corrales de 1 cerda; lechones 20 vs camadas ~10','Aclarar antes de entregar.','Productor / equipo',6),
 ('norma_nom001','norma','NOM-001-SEMARNAT-2021: descargas de aguas residuales','Verificar vigencia y aplicabilidad.','DOF / SEMARNAT',7),
 ('norma_nom087','norma','NOM-087-SEMARNAT-SSA1-2002: residuos peligrosos biológico-infecciosos','Agujas y vacunas.','DOF',8),
 ('norma_nom061','norma','NOM-061-ZOO-1999: alimentos para consumo animal','Alimento y aditivos.','DOF / SENASICA',9),
 ('norma_nom051','norma','NOM-051-ZOO-1995: trato humanitario en movilización','Transporte.','DOF',10),
 ('norma_nom064','norma','NOM-064-ZOO-2000: clasificación y prescripción de fármacos','Medicamentos.','DOF',11),
 ('mitigacion_n','mitigacion','Exceso de N: ajustar proteína y complementar aminoácidos','Menos N excretado.','PC % actual vs. requerida por fase',12),
 ('mitigacion_p','mitigacion','Exceso de P: fitasa en la dieta','Menos P excretado.','P % de la mezcla; si ya usa fitasa',13),
 ('mitigacion_agua','mitigacion','Volumen de agua en excreta: revisar bebederos y lavado','Menos efluente.','Agua medida vs. estimada',14),
 ('mitigacion_estercolero','mitigacion','Almacenamiento: compostaje o estercolero cubierto','Menos olor, moscas y escurrimiento.','Cuánto estiércol se acumula y dónde',15)
on conflict (id) do nothing;

notify pgrst,'reload schema';
commit;
