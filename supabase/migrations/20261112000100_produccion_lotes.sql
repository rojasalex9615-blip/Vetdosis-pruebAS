-- 15K: produccion animal (lotes, registros diarios y eventos).
-- Aplicada en Supabase Pruebas el 12 de noviembre de 2026.
-- Multi-clinica, RLS por rol, contrato JSONB validado e historial diario.
begin;

create table if not exists public.produccion_especies (
  code text primary key check (code ~ '^[a-z][a-z0-9_]{2,39}$'),
  nombre text not null check (char_length(btrim(nombre)) between 3 and 80),
  grupo text not null check (grupo in ('mamifero','ave','pez','crustaceo','insecto')),
  activo boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.produccion_especies_propositos (
  especie text not null references public.produccion_especies(code) on delete cascade,
  proposito text not null check (proposito in ('leche','carne','engorda','postura','mixto')),
  primary key (especie, proposito)
);

create table if not exists public.produccion_metricas (
  especie text not null references public.produccion_especies(code) on delete cascade,
  clave text not null check (clave ~ '^[a-z][a-z0-9_]{2,39}$'),
  etiqueta text not null check (char_length(btrim(etiqueta)) between 3 and 80),
  unidad text not null check (char_length(btrim(unidad)) between 1 and 16),
  minimo numeric,
  maximo numeric,
  primary key (especie, clave),
  check (minimo is null or maximo is null or minimo <= maximo)
);

insert into public.produccion_especies(code,nombre,grupo) values
 ('bovino','Bovino','mamifero'),('ovino','Ovino','mamifero'),('caprino','Caprino','mamifero'),
 ('cerdo','Cerdo','mamifero'),('gallina','Gallina','ave'),('pavo','Pavo','ave'),
 ('tilapia','Tilapia','pez'),('langostino','Langostino','crustaceo'),('abeja','Abeja','insecto')
on conflict (code) do nothing;

insert into public.produccion_especies_propositos(especie,proposito) values
 ('bovino','leche'),('bovino','carne'),('bovino','mixto'),
 ('ovino','carne'),('ovino','leche'),('caprino','leche'),('caprino','carne'),
 ('cerdo','engorda'),('cerdo','mixto'),('gallina','postura'),('gallina','engorda'),
 ('pavo','engorda'),('tilapia','engorda'),('langostino','engorda'),('abeja','mixto')
on conflict do nothing;

insert into public.produccion_metricas(especie,clave,etiqueta,unidad,minimo,maximo)
select e.code,m.clave,m.etiqueta,m.unidad,m.minimo,m.maximo
from public.produccion_especies e
cross join (values
 ('alimento_kg','Alimento suministrado','kg',0::numeric,1000000::numeric),
 ('peso_promedio_g','Peso promedio por animal','g',0::numeric,2000000::numeric),
 ('temperatura_c','Temperatura ambiente','grados C',(-20)::numeric,60::numeric)
) as m(clave,etiqueta,unidad,minimo,maximo)
on conflict do nothing;

insert into public.produccion_metricas(especie,clave,etiqueta,unidad,minimo,maximo) values
 ('bovino','leche_litros','Leche producida','L',0,100000),
 ('bovino','grasa_pct','Grasa de la leche','%',0,100),
 ('bovino','proteina_pct','Proteina de la leche','%',0,100),
 ('ovino','leche_litros','Leche producida','L',0,100000),
 ('ovino','lana_kg','Lana esquilada','kg',0,1000),
 ('caprino','leche_litros','Leche producida','L',0,100000),
 ('cerdo','peso_total_kg','Peso total del lote','kg',0,2000000),
 ('gallina','huevos_total','Huevos recolectados','huevo',0,1000000),
 ('gallina','huevos_roto','Huevos rotos o sucios','huevo',0,1000000),
 ('gallina','peso_huevo_g','Peso promedio del huevo','g',0,200),
 ('tilapia','ph_agua','pH del agua','pH',0,14),
 ('tilapia','oxigeno_mg_l','Oxigeno disuelto','mg/L',0,30),
 ('tilapia','biomasa_kg','Biomasa estimada','kg',0,1000000),
 ('langostino','ph_agua','pH del agua','pH',0,14),
 ('langostino','oxigeno_mg_l','Oxigeno disuelto','mg/L',0,30),
 ('langostino','biomasa_kg','Biomasa estimada','kg',0,1000000),
 ('abeja','miel_kg','Miel cosechada','kg',0,100000),
 ('abeja','peso_colmena_kg','Peso de colmena','kg',0,1000)
on conflict do nothing;

create table if not exists public.lotes_produccion (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  codigo text not null check (char_length(btrim(codigo)) between 1 and 40),
  nombre text not null check (char_length(btrim(nombre)) between 1 and 120),
  especie text not null,
  proposito text not null,
  sistema text check (sistema is null or sistema in ('piso','jaula','corral','pastoreo','estanque','colmena','otro')),
  fecha_inicio date not null default current_date,
  fecha_fin date,
  cabezas integer not null check (cabezas between 1 and 1000000),
  identificador_hato text check (identificador_hato is null or char_length(btrim(identificador_hato)) between 1 and 80),
  estado text not null default 'activo' check (estado in ('activo','cerrado')),
  atributos jsonb not null default '{}'::jsonb check (jsonb_typeof(atributos)='object' and octet_length(atributos::text)<=8000),
  version integer not null default 1 check (version>0),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (clinic_id, codigo),
  unique (id, clinic_id),
  foreign key (especie, proposito) references public.produccion_especies_propositos(especie, proposito),
  check (fecha_fin is null or fecha_fin >= fecha_inicio)
);

create table if not exists public.produccion_registros (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null,
  lote_id uuid not null,
  fecha date not null,
  metricas jsonb not null check (jsonb_typeof(metricas)='object' and octet_length(metricas::text)<=6000 and metricas <> '{}'::jsonb),
  notas text not null default '' check (char_length(notas)<=2000),
  registrado_por uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (lote_id, fecha),
  foreign key (lote_id, clinic_id) references public.lotes_produccion(id, clinic_id) on delete cascade
);

create table if not exists public.produccion_eventos (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null,
  lote_id uuid not null,
  fecha date not null,
  tipo text not null check (tipo in ('sanitario','mortalidad','pesaje','traslado','sacrificio','otro')),
  subtipo text not null default '' check (char_length(subtipo)<=60),
  animales_afectados integer check (animales_afectados is null or animales_afectados between 0 and 1000000),
  detalle jsonb not null default '{}'::jsonb check (jsonb_typeof(detalle)='object' and octet_length(detalle::text)<=6000),
  registrado_por uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  foreign key (lote_id, clinic_id) references public.lotes_produccion(id, clinic_id) on delete cascade,
  check (tipo<>'sanitario' or char_length(btrim(subtipo))>0)
);

create index if not exists produccion_registros_lote_fecha on public.produccion_registros(lote_id, fecha desc);
create index if not exists produccion_registros_clinic_fecha on public.produccion_registros(clinic_id, fecha desc);
create index if not exists produccion_registros_metricas_gin on public.produccion_registros using gin (metricas jsonb_path_ops);
create index if not exists produccion_eventos_clinic_tipo on public.produccion_eventos(clinic_id, tipo, fecha desc);
create index if not exists produccion_eventos_subtipo on public.produccion_eventos(clinic_id, lower(subtipo), fecha desc) where tipo='sanitario';
create index if not exists produccion_eventos_detalle_gin on public.produccion_eventos using gin (detalle jsonb_path_ops);
create index if not exists lotes_produccion_clinic_estado on public.lotes_produccion(clinic_id, estado, especie);

create or replace function private.produccion_metricas_ok(p_especie text,p_metricas jsonb)
returns boolean language sql stable set search_path='' as $$
 select coalesce(jsonb_typeof(p_metricas)='object',false)
  and coalesce(octet_length(p_metricas::text)<=6000,false)
  and not exists(
   select 1 from jsonb_each(case when jsonb_typeof(p_metricas)='object' then p_metricas else '{}'::jsonb end) m
   where jsonb_typeof(m.value)<>'number'
    or not exists(select 1 from public.produccion_metricas c
      where c.especie=p_especie and c.clave=m.key
       and (c.minimo is null or (m.value#>>'{}')::numeric>=c.minimo)
       and (c.maximo is null or (m.value#>>'{}')::numeric<=c.maximo)));
$$;
revoke all on function private.produccion_metricas_ok(text,jsonb) from public,anon,authenticated;

create or replace function private.produccion_registro_validar()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_especie text;v_estado text;
begin
 select l.especie,l.estado into v_especie,v_estado from public.lotes_produccion l where l.id=new.lote_id and l.clinic_id=new.clinic_id;
 if v_especie is null then raise exception 'lote_not_found';end if;
 if v_estado<>'activo' then raise exception 'lote_closed';end if;
 if not private.produccion_metricas_ok(v_especie,new.metricas) then raise exception 'produccion_metricas_invalidas';end if;
 return new;
end$$;
revoke all on function private.produccion_registro_validar() from public,anon,authenticated;
drop trigger if exists produccion_registro_validate on public.produccion_registros;
create trigger produccion_registro_validate before insert or update on public.produccion_registros
 for each row execute function private.produccion_registro_validar();

alter table public.produccion_especies enable row level security;
alter table public.produccion_especies_propositos enable row level security;
alter table public.produccion_metricas enable row level security;
alter table public.lotes_produccion enable row level security;
alter table public.produccion_registros enable row level security;
alter table public.produccion_eventos enable row level security;

revoke all on public.produccion_especies,public.produccion_especies_propositos,public.produccion_metricas,public.lotes_produccion,public.produccion_registros,public.produccion_eventos from public,anon,authenticated;
grant select on public.produccion_especies,public.produccion_especies_propositos,public.produccion_metricas to authenticated;
grant select on public.lotes_produccion,public.produccion_registros,public.produccion_eventos to authenticated;

drop policy if exists produccion_catalogo_read on public.produccion_especies;
create policy produccion_catalogo_read on public.produccion_especies for select to authenticated using (auth.uid() is not null);
drop policy if exists produccion_propositos_read on public.produccion_especies_propositos;
create policy produccion_propositos_read on public.produccion_especies_propositos for select to authenticated using (auth.uid() is not null);
drop policy if exists produccion_metricas_read on public.produccion_metricas;
create policy produccion_metricas_read on public.produccion_metricas for select to authenticated using (auth.uid() is not null);
drop policy if exists lotes_produccion_read on public.lotes_produccion;
create policy lotes_produccion_read on public.lotes_produccion for select to authenticated using (private.has_clinic_role(clinic_id));
drop policy if exists produccion_registros_read on public.produccion_registros;
create policy produccion_registros_read on public.produccion_registros for select to authenticated using (private.has_clinic_role(clinic_id));
drop policy if exists produccion_eventos_read on public.produccion_eventos;
create policy produccion_eventos_read on public.produccion_eventos for select to authenticated using (private.has_clinic_role(clinic_id));

create or replace function public.produccion_lote_guardar(p_clinic uuid,p_data jsonb,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;v_fp jsonb;v_version integer;
begin
 if auth.uid() is null then raise exception 'authentication_required';end if;
 if not private.has_clinic_role(p_clinic,array['admin','mvz']::text[]) then raise exception 'admin_or_mvz_required';end if;
 if jsonb_typeof(p_data) is distinct from 'object' or octet_length(p_data::text)>20000 then raise exception 'invalid_data';end if;
 if exists(select 1 from jsonb_object_keys(p_data) k where k not in ('id','codigo','nombre','especie','proposito','sistema','fecha_inicio','fecha_fin','cabezas','identificador_hato','estado','atributos','version')) then raise exception 'invalid_fields';end if;
 if coalesce(btrim(p_data->>'codigo'),'')='' or coalesce(btrim(p_data->>'nombre'),'')='' or coalesce(p_data->>'especie','')='' or coalesce(p_data->>'proposito','')='' or coalesce(p_data->>'cabezas','')!~'^[0-9]{1,7}$' then raise exception 'lote_fields_required';end if;
 if p_data?'atributos' and jsonb_typeof(p_data->'atributos') is distinct from 'object' then raise exception 'invalid_atributos';end if;
 v_fp=jsonb_build_object('kind','produccion_lote','data',p_data);
 v_id=private.vet_receipt(p_clinic,p_operation,v_fp);if v_id is not null then return v_id;end if;
 perform 1 from public.clinics where id=p_clinic for update;
 v_id=nullif(p_data->>'id','')::uuid;
 if v_id is null then
  insert into public.lotes_produccion(clinic_id,codigo,nombre,especie,proposito,sistema,fecha_inicio,fecha_fin,cabezas,identificador_hato,estado,atributos,created_by)
  values(p_clinic,btrim(p_data->>'codigo'),btrim(p_data->>'nombre'),p_data->>'especie',p_data->>'proposito',nullif(p_data->>'sistema',''),coalesce((p_data->>'fecha_inicio')::date,current_date),nullif(p_data->>'fecha_fin','')::date,(p_data->>'cabezas')::integer,nullif(btrim(coalesce(p_data->>'identificador_hato','')),''),coalesce(nullif(p_data->>'estado',''),'activo'),coalesce(p_data->'atributos','{}'::jsonb),auth.uid())
  returning id into v_id;
 else
  if coalesce(p_data->>'version','')!~'^[0-9]{1,9}$' then raise exception 'version_required';end if;
  v_version=(p_data->>'version')::integer;
  if p_data->>'especie' is not null and exists(select 1 from public.lotes_produccion l where l.id=v_id and l.clinic_id=p_clinic and l.especie<>p_data->>'especie')
   and exists(select 1 from public.produccion_registros r where r.lote_id=v_id and r.clinic_id=p_clinic) then raise exception 'especie_locked_with_records';end if;
  update public.lotes_produccion set codigo=btrim(p_data->>'codigo'),nombre=btrim(p_data->>'nombre'),especie=p_data->>'especie',proposito=p_data->>'proposito',sistema=nullif(p_data->>'sistema',''),fecha_inicio=coalesce((p_data->>'fecha_inicio')::date,fecha_inicio),fecha_fin=nullif(p_data->>'fecha_fin','')::date,cabezas=(p_data->>'cabezas')::integer,identificador_hato=nullif(btrim(coalesce(p_data->>'identificador_hato','')),''),estado=coalesce(nullif(p_data->>'estado',''),estado),atributos=coalesce(p_data->'atributos',atributos),version=version+1,updated_at=clock_timestamp()
  where id=v_id and clinic_id=p_clinic and version=v_version;
  if not found then raise exception 'version_conflict_or_not_found';end if;
 end if;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details) values(p_clinic,auth.uid(),'produccion_lote_saved',v_id::text,jsonb_build_object('especie',p_data->>'especie','proposito',p_data->>'proposito','cabezas',p_data->>'cabezas'));
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,v_fp,v_id);
 return v_id;
end$$;

create or replace function public.produccion_registro_guardar(p_clinic uuid,p_lote uuid,p_fecha date,p_metricas jsonb,p_notas text,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;v_fp jsonb;v_especie text;
begin
 if auth.uid() is null then raise exception 'authentication_required';end if;
 if not private.has_clinic_role(p_clinic,array['admin','mvz','auxiliar']::text[]) then raise exception 'produccion_write_required';end if;
 if p_fecha is null or p_fecha>current_date then raise exception 'invalid_fecha';end if;
 if jsonb_typeof(p_metricas) is distinct from 'object' or p_metricas='{}'::jsonb then raise exception 'metricas_required';end if;
 if char_length(coalesce(p_notas,''))>2000 then raise exception 'notas_too_long';end if;
 select especie into v_especie from public.lotes_produccion where id=p_lote and clinic_id=p_clinic;
 if v_especie is null then raise exception 'lote_not_found';end if;
 if not private.produccion_metricas_ok(v_especie,p_metricas) then raise exception 'metricas_invalidas';end if;
 v_fp=jsonb_build_object('kind','produccion_registro','lote',p_lote,'fecha',p_fecha,'metricas',p_metricas,'notas',coalesce(p_notas,''));
 v_id=private.vet_receipt(p_clinic,p_operation,v_fp);if v_id is not null then return v_id;end if;
 perform 1 from public.clinics where id=p_clinic for update;
 insert into public.produccion_registros(clinic_id,lote_id,fecha,metricas,notas,registrado_por)
 values(p_clinic,p_lote,p_fecha,p_metricas,btrim(coalesce(p_notas,'')),auth.uid())
 on conflict(lote_id,fecha) do update set metricas=excluded.metricas,notas=excluded.notas,registrado_por=excluded.registrado_por,updated_at=clock_timestamp()
 returning id into v_id;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details) values(p_clinic,auth.uid(),'produccion_registro_saved',v_id::text,jsonb_build_object('lote_id',p_lote,'fecha',p_fecha));
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,v_fp,v_id);
 return v_id;
end$$;

create or replace function public.produccion_evento_guardar(p_clinic uuid,p_lote uuid,p_fecha date,p_tipo text,p_subtipo text,p_animales integer,p_detalle jsonb,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;v_fp jsonb;
begin
 if auth.uid() is null then raise exception 'authentication_required';end if;
 if not private.has_clinic_role(p_clinic,array['admin','mvz','auxiliar']::text[]) then raise exception 'produccion_write_required';end if;
 if p_fecha is null or p_fecha>current_date then raise exception 'invalid_fecha';end if;
 if p_tipo is null or p_tipo not in ('sanitario','mortalidad','pesaje','traslado','sacrificio','otro') then raise exception 'invalid_tipo';end if;
 if char_length(btrim(coalesce(p_subtipo,'')))>60 then raise exception 'subtipo_too_long';end if;
 if p_tipo='sanitario' and char_length(btrim(coalesce(p_subtipo,'')))<1 then raise exception 'subtipo_required';end if;
 if p_animales is not null and (p_animales<0 or p_animales>1000000) then raise exception 'invalid_animales';end if;
 if jsonb_typeof(coalesce(p_detalle,'{}'::jsonb)) is distinct from 'object' or octet_length(coalesce(p_detalle,'{}'::jsonb)::text)>6000 then raise exception 'invalid_detalle';end if;
 if not exists(select 1 from public.lotes_produccion where id=p_lote and clinic_id=p_clinic) then raise exception 'lote_not_found';end if;
 v_fp=jsonb_build_object('kind','produccion_evento','lote',p_lote,'fecha',p_fecha,'tipo',p_tipo,'subtipo',coalesce(p_subtipo,''),'animales',p_animales,'detalle',coalesce(p_detalle,'{}'::jsonb));
 v_id=private.vet_receipt(p_clinic,p_operation,v_fp);if v_id is not null then return v_id;end if;
 perform 1 from public.clinics where id=p_clinic for update;
 insert into public.produccion_eventos(clinic_id,lote_id,fecha,tipo,subtipo,animales_afectados,detalle,registrado_por)
 values(p_clinic,p_lote,p_fecha,p_tipo,btrim(coalesce(p_subtipo,'')),p_animales,coalesce(p_detalle,'{}'::jsonb),auth.uid())
 returning id into v_id;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details) values(p_clinic,auth.uid(),'produccion_evento_saved',v_id::text,jsonb_build_object('lote_id',p_lote,'tipo',p_tipo,'subtipo',coalesce(p_subtipo,'')));
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,v_fp,v_id);
 return v_id;
end$$;

revoke all on function public.produccion_lote_guardar(uuid,jsonb,text),public.produccion_registro_guardar(uuid,uuid,date,jsonb,text,text),public.produccion_evento_guardar(uuid,uuid,date,text,text,integer,jsonb,text) from public,anon;
grant execute on function public.produccion_lote_guardar(uuid,jsonb,text),public.produccion_registro_guardar(uuid,uuid,date,jsonb,text,text),public.produccion_evento_guardar(uuid,uuid,date,text,text,integer,jsonb,text) to authenticated;

notify pgrst,'reload schema';
commit;
