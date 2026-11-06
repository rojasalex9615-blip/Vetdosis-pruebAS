-- CANDIDATO, NO APLICADO. Sin probar contra una base real; requiere revisión
-- (CodeRabbit/GPT-6) y autorización explícita de Ale antes de aplicar en Pruebas.
-- Origen: SQL de Gemini (Drive, 06-nov-2026), reescrito a la convención del repo:
-- todo por clinic_id, RLS por membresía, sin acceso anon, escritura solo por RPC.
-- Cambios respecto al original de Gemini:
--  * El original usaba policies "USING (true)": cualquier usuario autenticado de
--    cualquier clínica leía y escribía todo. Aquí cada fila lleva clinic_id.
--  * GRANT SELECT a anon eliminado (exponía granjas sin sesión).
--  * Catálogo universal: solo lectura para autenticados (el original permitía editarlo).
--  * Lotes y balance ahora llevan clinic_id, con FK compuesta para que no puedan
--    apuntar a una UPP de otra clínica.
--  * CHECKs alineados con lib/modules/production/domain/growth_calculation.dart.
-- Número 15K tomado tras 15J; anunciar en #31 antes de usarlo (puede solaparse).
begin;
do $prerequisites$
begin
 if to_regclass('public.clinics') is null or to_regclass('public.clinic_members') is null
 or to_regclass('public.audit_log') is null
 or to_regprocedure('private.has_clinic_role(uuid,text[])') is null
 or to_regprocedure('private.vet_receipt(uuid,text,jsonb)') is null then
  raise exception 'porcino_prerequisite_missing';
 end if;
end
$prerequisites$;

create table public.porcino_fases_catalogo (
 id uuid primary key default gen_random_uuid(),
 nombre_fase text not null unique,
 dias_duracion_estandar int check (dias_duracion_estandar > 0),
 peso_inicial_estandar_kg numeric check (peso_inicial_estandar_kg > 0),
 peso_final_estandar_kg numeric check (peso_final_estandar_kg > 0),
 consumo_diario_estandar_kg numeric check (consumo_diario_estandar_kg > 0),
 proteina_requerida_porcentaje numeric check (proteina_requerida_porcentaje between 0 and 100),
 fosforo_requerido_porcentaje numeric check (fosforo_requerido_porcentaje between 0 and 100),
 espacio_requerido_m2 numeric check (espacio_requerido_m2 > 0),
 fuente_referencia text not null default 'por validar',
 created_at timestamptz not null default clock_timestamp()
);

create table public.porcino_upp_config (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id),
 nombre_upp text not null check (btrim(nombre_upp) <> ''),
 flujo_bandas_dias int not null default 7 check (flujo_bandas_dias > 0),
 vientres_inventario int not null check (vientres_inventario > 0),
 porcentaje_desperdicio_agua numeric not null default 10 check (porcentaje_desperdicio_agua between 0 and 100),
 limite_nitrogeno_hectarea numeric check (limite_nitrogeno_hectarea > 0),
 version int not null default 1,
 created_by uuid not null default auth.uid(),
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(),
 unique (id, clinic_id)
);

create table public.porcino_lotes_calculo (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id),
 upp_id uuid not null,
 fase_id uuid references public.porcino_fases_catalogo(id),
 animales_pesados int not null check (animales_pesados > 0),
 dias_transcurridos int not null check (dias_transcurridos > 0),
 peso_total_inicial_kg numeric not null check (peso_total_inicial_kg > 0),
 peso_total_final_kg numeric not null,
 alimento_consumido_kg numeric not null check (alimento_consumido_kg > 0),
 costo_alimento_mxn numeric check (costo_alimento_mxn >= 0),
 es_mismo_grupo boolean not null default true check (es_mismo_grupo),
 ganancia_diaria_peso numeric generated always as
  ((peso_total_final_kg - peso_total_inicial_kg) / (animales_pesados * dias_transcurridos)) stored,
 conversion_alimenticia numeric generated always as
  (alimento_consumido_kg / (peso_total_final_kg - peso_total_inicial_kg)) stored,
 created_by uuid not null default auth.uid(),
 created_at timestamptz not null default clock_timestamp(),
 check (peso_total_final_kg > peso_total_inicial_kg),
 unique (id, clinic_id),
 foreign key (upp_id, clinic_id) references public.porcino_upp_config(id, clinic_id)
);

create table public.porcino_balance_ambiental (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references public.clinics(id),
 lote_id uuid not null,
 nitrogeno_ingerido_kg numeric not null check (nitrogeno_ingerido_kg >= 0),
 nitrogeno_retenido_kg numeric not null check (nitrogeno_retenido_kg >= 0),
 nitrogeno_excretado_kg numeric generated always as (nitrogeno_ingerido_kg - nitrogeno_retenido_kg) stored,
 volumen_purin_estimado_l numeric check (volumen_purin_estimado_l >= 0),
 superficie_agricola_necesaria_ha numeric check (superficie_agricola_necesaria_ha >= 0),
 created_by uuid not null default auth.uid(),
 created_at timestamptz not null default clock_timestamp(),
 check (nitrogeno_retenido_kg <= nitrogeno_ingerido_kg),
 foreign key (lote_id, clinic_id) references public.porcino_lotes_calculo(id, clinic_id)
);

create index porcino_upp_config_clinic_idx on public.porcino_upp_config(clinic_id);
create index porcino_lotes_calculo_clinic_upp_idx on public.porcino_lotes_calculo(clinic_id, upp_id);
create index porcino_lotes_calculo_fase_idx on public.porcino_lotes_calculo(fase_id);
create index porcino_balance_ambiental_clinic_lote_idx on public.porcino_balance_ambiental(clinic_id, lote_id);

alter table public.porcino_fases_catalogo enable row level security;
alter table public.porcino_upp_config enable row level security;
alter table public.porcino_lotes_calculo enable row level security;
alter table public.porcino_balance_ambiental enable row level security;

revoke all on public.porcino_fases_catalogo, public.porcino_upp_config,
 public.porcino_lotes_calculo, public.porcino_balance_ambiental from public, anon, authenticated;
grant select on public.porcino_fases_catalogo, public.porcino_upp_config,
 public.porcino_lotes_calculo, public.porcino_balance_ambiental to authenticated;

create policy porcino_catalogo_read on public.porcino_fases_catalogo
 for select to authenticated using (true);
create policy porcino_upp_read on public.porcino_upp_config
 for select to authenticated using (exists(select 1 from public.clinic_members m
  where m.clinic_id=porcino_upp_config.clinic_id and m.user_id=(select auth.uid())));
create policy porcino_lotes_read on public.porcino_lotes_calculo
 for select to authenticated using (exists(select 1 from public.clinic_members m
  where m.clinic_id=porcino_lotes_calculo.clinic_id and m.user_id=(select auth.uid())));
create policy porcino_balance_read on public.porcino_balance_ambiental
 for select to authenticated using (exists(select 1 from public.clinic_members m
  where m.clinic_id=porcino_balance_ambiental.clinic_id and m.user_id=(select auth.uid())));

-- Escritura: un solo RPC idempotente (recibo de operación) para guardar un lote.
-- Rol permitido: admin o mvz de la clínica. Falta (pendiente de decidir): RPC para
-- crear/editar la UPP y para el balance ambiental; mismo patrón.
create or replace function public.porcino_lote_guardar(p_clinic uuid,p_data jsonb,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;fp jsonb;
begin
 if auth.uid() is null then raise exception 'authentication_required';end if;
 perform 1 from public.clinic_members where clinic_id=p_clinic and user_id=auth.uid() for share;
 if not found then raise exception 'access_denied';end if;
 if not private.has_clinic_role(p_clinic,array['admin','mvz']) then raise exception 'role_required';end if;
 if jsonb_typeof(p_data) is distinct from 'object' or octet_length(p_data::text)>5000 then raise exception 'invalid_data';end if;
 fp=jsonb_build_object('kind','porcino_lote','data',p_data);
 v_id=private.vet_receipt(p_clinic,p_operation,fp);if v_id is not null then return v_id;end if;
 insert into public.porcino_lotes_calculo(clinic_id,upp_id,fase_id,animales_pesados,dias_transcurridos,
  peso_total_inicial_kg,peso_total_final_kg,alimento_consumido_kg,costo_alimento_mxn)
 values(p_clinic,(p_data->>'upp_id')::uuid,nullif(p_data->>'fase_id','')::uuid,(p_data->>'animales_pesados')::int,
  (p_data->>'dias_transcurridos')::int,(p_data->>'peso_total_inicial_kg')::numeric,
  (p_data->>'peso_total_final_kg')::numeric,(p_data->>'alimento_consumido_kg')::numeric,
  nullif(p_data->>'costo_alimento_mxn','')::numeric) returning id into v_id;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details)
 values(p_clinic,auth.uid(),'porcino_lote_guardar',v_id::text,'{}'::jsonb);
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,fp,v_id);
 return v_id;
end$$;
revoke all on function public.porcino_lote_guardar(uuid,jsonb,text) from public,anon;
grant execute on function public.porcino_lote_guardar(uuid,jsonb,text) to authenticated;

-- Datos base de Gemini (NRC 2012 / FEDNA), SIN VALIDAR por Claude. Diferencia
-- conocida: Lactancia 21 d aquí; las diapositivas de la clase usan 28 d (ciclo 149 d).
insert into public.porcino_fases_catalogo
(nombre_fase,dias_duracion_estandar,peso_inicial_estandar_kg,peso_final_estandar_kg,consumo_diario_estandar_kg,
 proteina_requerida_porcentaje,fosforo_requerido_porcentaje,espacio_requerido_m2,fuente_referencia) values
('Gestación',114,140,180,2.5,13.5,0.50,2.0,'Gemini: NRC 2012 / FEDNA — por validar'),
('Lactancia',21,180,165,5.8,17.5,0.60,4.0,'Gemini: NRC 2012 / FEDNA — por validar'),
('Lechón (Pre-inicio)',21,6,15,0.4,23.0,0.70,0.2,'Gemini: NRC 2012 / FEDNA — por validar'),
('Posdestete (Inicio)',28,15,30,1.0,20.0,0.60,0.3,'Gemini: NRC 2012 / FEDNA — por validar'),
('Desarrollo',40,30,70,2.0,17.0,0.55,0.6,'Gemini: NRC 2012 / FEDNA — por validar'),
('Engorda',45,70,115,2.8,14.5,0.45,0.9,'Gemini: NRC 2012 / FEDNA — por validar');

notify pgrst,'reload schema';
commit;
