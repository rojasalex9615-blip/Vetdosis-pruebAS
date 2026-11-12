-- M15 (aditivo): aves de postura — catálogo de referencias, casetas, parvadas,
-- registros productivos y eventos sanitarios.
--
-- Aplicar UNA sola vez sobre la base existente, después de revisar privilegios.
-- No modifica tablas, políticas ni funciones anteriores. No borra datos.
--
-- Acceso: solo por RPC SECURITY DEFINER. Las tablas no conceden privilegios a
-- anon ni authenticated; sin políticas RLS, el acceso directo queda denegado.
-- Roles: lectura para cualquier integrante; escritura para admin, MVZ y auxiliar;
-- crear/cerrar parvadas y editar aves iniciales, solo admin y MVZ.
begin;

-- 1. Catálogo de referencias (mismos valores que assets/clinical/aviculture)
create table if not exists public.aviculture_references(
 id uuid primary key default gen_random_uuid(),
 etapa text not null check (btrim(etapa)<>''),
 semana_desde smallint check (semana_desde is null or semana_desde>=0),
 semana_hasta smallint check (semana_hasta is null or semana_hasta>=0),
 sistema text not null check (sistema in ('piso','jaula_bateria','ambos','general')),
 parametro text not null check (btrim(parametro)<>''),
 minimo numeric(12,3),
 maximo numeric(12,3),
 unidad text,
 fuente text,
 estado text not null check (estado in ('verificada','sin_verificar','pendiente')),
 orden integer not null default 0,
 check (minimo is null or maximo is null or minimo<=maximo),
 unique (etapa,sistema,parametro));

create table if not exists public.aviculture_equipment_references(
 id uuid primary key default gen_random_uuid(),
 etapa text not null check (btrim(etapa)<>''),
 equipo text not null check (btrim(equipo)<>''),
 aves_por_unidad_min numeric(12,3),
 aves_por_unidad_max numeric(12,3),
 nota text not null default '',
 fuente text,
 estado text not null check (estado in ('verificada','sin_verificar','pendiente')),
 orden integer not null default 0,
 check (aves_por_unidad_min is null or aves_por_unidad_max is null
  or aves_por_unidad_min<=aves_por_unidad_max),
 unique (etapa,equipo));

-- Datos de capacidad/espacio (12 filas). Se conservan tal como están en el CSV:
-- estado sin_verificar y su fuente textual, sin corregir ni extrapolar valores.
insert into public.aviculture_references
 (etapa,semana_desde,semana_hasta,sistema,parametro,minimo,maximo,unidad,fuente,estado,orden)
values
 ('crianza',0,6,'piso','densidad',12,15,'aves_por_m2','Clase Prod. Avicola Postura 15-sep-2026','sin_verificar',1),
 ('crianza',0,6,'jaula_bateria','espacio_por_ave',250,350,'cm2','Clase Prod. Avicola Postura 15-sep-2026','sin_verificar',2),
 ('crianza',0,6,'ambos','bebedero_lineal',1.5,1.5,'cm_por_ave','Clase Prod. Avicola Postura 15-sep-2026','sin_verificar',3),
 ('crianza',0,6,'ambos','comedero_lineal',3,3,'cm_por_ave','Clase Prod. Avicola Postura 15-sep-2026','sin_verificar',4),
 ('desarrollo',7,12,'piso','densidad',8,10,'aves_por_m2','Clase Prod. Avicola Postura 15-sep-2026','sin_verificar',5),
 ('desarrollo',7,12,'jaula_bateria','espacio_por_ave',350,450,'cm2','Clase Prod. Avicola Postura 15-sep-2026','sin_verificar',6),
 ('desarrollo',7,12,'ambos','bebedero_lineal',2.5,2.5,'cm_por_ave','Clase Prod. Avicola Postura 15-sep-2026','sin_verificar',7),
 ('desarrollo',7,12,'ambos','comedero_lineal',5,5,'cm_por_ave','Clase Prod. Avicola Postura 15-sep-2026','sin_verificar',8),
 ('postura',13,null,'piso','densidad',6,8,'aves_por_m2','Clase Prod. Avicola Postura 15-sep-2026','sin_verificar',9),
 ('postura',13,null,'jaula_bateria','espacio_por_ave',450,550,'cm2','Clase Prod. Avicola Postura 15-sep-2026','sin_verificar',10),
 ('postura',13,null,'ambos','bebedero_lineal',5,5,'cm_por_ave','Clase Prod. Avicola Postura 15-sep-2026','sin_verificar',11),
 ('postura',13,null,'ambos','comedero_lineal',7,7,'cm_por_ave','Clase Prod. Avicola Postura 15-sep-2026','sin_verificar',12)
on conflict (etapa,sistema,parametro) do nothing;

-- Parámetros sin fuente todavía. No se inventan valores: mínimo, máximo y
-- unidad quedan nulos y la UI debe mostrarlos como pendientes.
insert into public.aviculture_references
 (etapa,sistema,parametro,minimo,maximo,unidad,fuente,estado,orden)
values
 ('general','general','comedero_tolva',null,null,null,null,'pendiente',91),
 ('general','general','temperatura_por_edad',null,null,null,null,'pendiente',92),
 ('general','general','presion_agua',null,null,null,null,'pendiente',93)
on conflict (etapa,sistema,parametro) do nothing;

insert into public.aviculture_equipment_references
 (etapa,equipo,aves_por_unidad_min,aves_por_unidad_max,nota,fuente,estado,orden)
values
 ('inicio_primeros_8_12_dias','minitolva',100,100,'capacidad 3.5-4 kg por cada 100 aves','Apuntes Prod. Avicola','sin_verificar',1),
 ('inicio_primeros_8_12_dias','vitrolero',100,100,'capacidad 4 L por cada 100 aves','Apuntes Prod. Avicola','sin_verificar',2),
 ('crianza','bebedero_campana',80,100,'','Apuntes Prod. Avicola','sin_verificar',3),
 ('crianza_postura','comedero_automatico_plato',45,55,'','Apuntes Prod. Avicola','sin_verificar',4),
 ('crianza_postura','bebedero_niple',8,12,'por confirmar el rango','Apuntes Prod. Avicola','sin_verificar',5),
 ('crianza_postura','bebedero_copita',6,8,'por confirmar el rango','Apuntes Prod. Avicola','sin_verificar',6),
 ('inicio','criadora_calefactor',1500,2500,'40000 BTU/h por criadora','Apuntes Prod. Avicola','sin_verificar',7)
on conflict (etapa,equipo) do nothing;

-- 2. Casetas / galpones
create table if not exists public.aviculture_houses(
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null,
 name text not null check (btrim(name)<>'' and length(name)<=80),
 system text not null check (system in ('piso','jaula_bateria')),
 capacity_birds integer not null default 0 check (capacity_birds>=0),
 notes text not null default '' check (length(notes)<=1000),
 archived boolean not null default false,
 version integer not null default 1 check (version>0),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(),
 unique (clinic_id,id));
create unique index if not exists aviculture_houses_name_key
 on public.aviculture_houses(clinic_id,lower(btrim(name)));
create index if not exists aviculture_houses_list_idx
 on public.aviculture_houses(clinic_id,archived,name);

-- 3. Parvadas / ciclos
create table if not exists public.aviculture_flocks(
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null,
 house_id uuid,
 code text not null check (btrim(code)<>'' and length(code)<=30),
 genetic_line text not null default '' check (length(genetic_line)<=80),
 start_date date not null,
 initial_birds integer not null check (initial_birds between 1 and 1000000),
 status text not null default 'activa' check (status in ('activa','cerrada')),
 closed_on date,
 notes text not null default '' check (length(notes)<=1000),
 version integer not null default 1 check (version>0),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(),
 unique (clinic_id,id),
 unique (clinic_id,code),
 foreign key (clinic_id,house_id) references public.aviculture_houses(clinic_id,id),
 check (status='activa' or closed_on is not null),
 check (closed_on is null or closed_on>=start_date));
create index if not exists aviculture_flocks_list_idx
 on public.aviculture_flocks(clinic_id,status,start_date desc);

-- 4. Registros productivos (uno por parvada y día)
create table if not exists public.aviculture_production_records(
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null,
 flock_id uuid not null,
 record_date date not null,
 eggs integer not null default 0 check (eggs>=0),
 eggs_discarded integer not null default 0 check (eggs_discarded>=0),
 mortality integer not null default 0 check (mortality>=0),
 feed_kg numeric(10,3) not null default 0 check (feed_kg>=0),
 avg_weight_g numeric(8,1) check (avg_weight_g is null or avg_weight_g>0),
 water_l numeric(10,1) check (water_l is null or water_l>=0),
 notes text not null default '' check (length(notes)<=1000),
 version integer not null default 1 check (version>0),
 recorded_by uuid not null references auth.users(id),
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(),
 unique (clinic_id,id),
 unique (clinic_id,flock_id,record_date),
 foreign key (clinic_id,flock_id) references public.aviculture_flocks(clinic_id,id));
create index if not exists aviculture_records_recent_idx
 on public.aviculture_production_records(clinic_id,record_date desc,flock_id);

-- 5. Eventos de la parvada (sanidad, alimentación, seguimiento)
create table if not exists public.aviculture_flock_events(
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null,
 flock_id uuid not null,
 event_date date not null,
 kind text not null check (kind in
  ('vacunacion','tratamiento','desparasitacion','pesaje','alimentacion','inspeccion','otro')),
 title text not null check (btrim(title)<>'' and length(title)<=120),
 details text not null default '' check (length(details)<=2000),
 withdrawal_until date,
 version integer not null default 1 check (version>0),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default clock_timestamp(),
 unique (clinic_id,id),
 foreign key (clinic_id,flock_id) references public.aviculture_flocks(clinic_id,id),
 check (withdrawal_until is null or withdrawal_until>=event_date));
create index if not exists aviculture_events_recent_idx
 on public.aviculture_flock_events(clinic_id,event_date desc,flock_id);

-- 6. Privilegios y RLS: el cliente nunca toca las tablas directamente
alter table public.aviculture_references enable row level security;
alter table public.aviculture_equipment_references enable row level security;
alter table public.aviculture_houses enable row level security;
alter table public.aviculture_flocks enable row level security;
alter table public.aviculture_production_records enable row level security;
alter table public.aviculture_flock_events enable row level security;
revoke all on public.aviculture_references,public.aviculture_equipment_references,
 public.aviculture_houses,public.aviculture_flocks,
 public.aviculture_production_records,public.aviculture_flock_events
 from public,anon,authenticated;

-- 7. Guardas y conversión de datos
create or replace function private.avi_guard(p_clinic uuid,p_write boolean,p_lead boolean)
returns text language plpgsql stable security definer set search_path='' as $$
declare r text;
begin
 if auth.uid() is null or p_clinic is null then raise exception 'access_denied';end if;
 select m.role::text into r from public.clinic_members m
  where m.clinic_id=p_clinic and m.user_id=auth.uid();
 if r is null then raise exception 'access_denied';end if;
 if p_write and r not in ('admin','mvz','auxiliar') then raise exception 'write_role_required';end if;
 if p_lead and r not in ('admin','mvz') then raise exception 'lead_role_required';end if;
 return r;
end$$;
revoke all on function private.avi_guard(uuid,boolean,boolean) from public,anon,authenticated;

create or replace function private.avi_int(p_data jsonb,p_key text,p_min bigint,p_max bigint,p_default bigint)
returns bigint language plpgsql immutable set search_path='' as $$
declare t text;n bigint;
begin
 t=btrim(coalesce(p_data->>p_key,''));
 if t='' then return p_default;end if;
 if t !~ '^[0-9]{1,12}$' then raise exception 'invalid_data';end if;
 n=t::bigint;
 if n<p_min or n>p_max then raise exception 'invalid_data';end if;
 return n;
end$$;
revoke all on function private.avi_int(jsonb,text,bigint,bigint,bigint) from public,anon,authenticated;

create or replace function private.avi_num(p_data jsonb,p_key text,p_max numeric,p_default numeric)
returns numeric language plpgsql immutable set search_path='' as $$
declare t text;n numeric;
begin
 t=btrim(coalesce(p_data->>p_key,''));
 if t='' then return p_default;end if;
 if t !~ '^[0-9]{1,9}(\.[0-9]{1,3})?$' then raise exception 'invalid_data';end if;
 n=t::numeric;
 if n<0 or n>p_max then raise exception 'invalid_data';end if;
 return n;
end$$;
revoke all on function private.avi_num(jsonb,text,numeric,numeric) from public,anon,authenticated;

create or replace function private.avi_text(p_data jsonb,p_key text,p_max integer,p_required boolean)
returns text language plpgsql immutable set search_path='' as $$
declare t text;
begin
 if p_data ? p_key and jsonb_typeof(p_data->p_key) is distinct from 'string' then
  raise exception 'invalid_data';
 end if;
 t=btrim(coalesce(p_data->>p_key,''));
 if p_required and t='' then raise exception 'invalid_data';end if;
 if length(t)>p_max then raise exception 'invalid_data';end if;
 return t;
end$$;
revoke all on function private.avi_text(jsonb,text,integer,boolean) from public,anon,authenticated;

-- 8. Lectura: un solo snapshot por clínica
create or replace function public.avi_workspace(p_clinic uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare tz text;d date;can_write boolean;
begin
 perform private.avi_guard(p_clinic,false,false);
 select coalesce(s.timezone,'America/Mexico_City') into tz
  from public.inventory_clinic_settings s where s.clinic_id=p_clinic;
 tz=coalesce(tz,'America/Mexico_City');
 d=(statement_timestamp() at time zone tz)::date;
 select m.role::text in ('admin','mvz','auxiliar') into can_write
  from public.clinic_members m where m.clinic_id=p_clinic and m.user_id=auth.uid();
 return jsonb_build_object(
  'schema_version',1,'clinic_id',p_clinic,'day',d,'timezone',tz,
  'can_write',coalesce(can_write,false),
  'references',(
   select coalesce(jsonb_agg(jsonb_build_object(
    'id',r.id,'stage',r.etapa,'week_from',r.semana_desde,'week_to',r.semana_hasta,
    'system',r.sistema,'parameter',r.parametro,'min',r.minimo,'max',r.maximo,
    'unit',r.unidad,'source',r.fuente,'status',r.estado) order by r.orden,r.parametro),'[]')
   from public.aviculture_references r),
  'equipment',(
   select coalesce(jsonb_agg(jsonb_build_object(
    'id',e.id,'stage',e.etapa,'equipment',e.equipo,
    'birds_per_unit_min',e.aves_por_unidad_min,'birds_per_unit_max',e.aves_por_unidad_max,
    'note',e.nota,'source',e.fuente,'status',e.estado) order by e.orden,e.equipo),'[]')
   from public.aviculture_equipment_references e),
  'houses',(
   select coalesce(jsonb_agg(jsonb_build_object(
    'id',h.id,'name',h.name,'system',h.system,'capacity',h.capacity_birds,
    'notes',h.notes,'archived',h.archived,'version',h.version) order by h.archived,h.name),'[]')
   from public.aviculture_houses h where h.clinic_id=p_clinic),
  'flocks',(
   select coalesce(jsonb_agg(jsonb_build_object(
    'id',f.id,'code',f.code,'house_id',f.house_id,'house',h.name,'system',h.system,
    'genetic_line',f.genetic_line,'start_date',f.start_date,'status',f.status,
    'closed_on',f.closed_on,'initial_birds',f.initial_birds,'version',f.version,
    'week',greatest(1,((d-f.start_date)/7)+1),
    'birds',greatest(0,f.initial_birds-coalesce(a.mortality,0)),
    'mortality_total',coalesce(a.mortality,0),
    'mortality_pct',case when f.initial_birds>0 then
     round(coalesce(a.mortality,0)*100.0/f.initial_birds,2) else 0 end,
    'eggs_total',coalesce(a.eggs,0),
    'feed_kg_total',round(coalesce(a.feed_kg,0),3),
    'records',coalesce(a.records,0),
    'last_record',a.last_date,
    'last_eggs',a.last_eggs,
    'laying_pct',case when f.initial_birds-coalesce(a.mortality,0)>0 and a.last_eggs is not null
     then round(a.last_eggs*100.0/(f.initial_birds-coalesce(a.mortality,0)),2) end,
    'feed_g_bird_day',case when f.initial_birds-coalesce(a.mortality,0)>0 and a.last_feed is not null
     then round(a.last_feed*1000/(f.initial_birds-coalesce(a.mortality,0)),1) end)
    order by f.status,f.start_date desc,f.code),'[]')
   from public.aviculture_flocks f
   left join public.aviculture_houses h on h.clinic_id=f.clinic_id and h.id=f.house_id
   left join lateral (
    select sum(p.mortality) mortality,sum(p.eggs) eggs,sum(p.feed_kg) feed_kg,count(*) records,
     max(p.record_date) last_date,
     (array_agg(p.eggs order by p.record_date desc))[1] last_eggs,
     (array_agg(p.feed_kg order by p.record_date desc))[1] last_feed
    from public.aviculture_production_records p
    where p.clinic_id=f.clinic_id and p.flock_id=f.id) a on true
   where f.clinic_id=p_clinic),
  'records',(
   select coalesce(jsonb_agg(jsonb_build_object(
    'id',p.id,'flock_id',p.flock_id,'flock',f.code,'date',p.record_date,
    'eggs',p.eggs,'eggs_discarded',p.eggs_discarded,'mortality',p.mortality,
    'feed_kg',p.feed_kg,'avg_weight_g',p.avg_weight_g,'water_l',p.water_l,
    'notes',p.notes,'version',p.version) order by p.record_date desc,p.created_at desc),'[]')
   from (select * from public.aviculture_production_records
    where clinic_id=p_clinic order by record_date desc,created_at desc limit 400) p
   join public.aviculture_flocks f on f.clinic_id=p.clinic_id and f.id=p.flock_id),
  'events',(
   select coalesce(jsonb_agg(jsonb_build_object(
    'id',e.id,'flock_id',e.flock_id,'flock',f.code,'date',e.event_date,'kind',e.kind,
    'title',e.title,'details',e.details,'withdrawal_until',e.withdrawal_until,
    'version',e.version) order by e.event_date desc,e.created_at desc),'[]')
   from (select * from public.aviculture_flock_events
    where clinic_id=p_clinic order by event_date desc,created_at desc limit 200) e
   join public.aviculture_flocks f on f.clinic_id=e.clinic_id and f.id=e.flock_id));
end$$;

-- 9. Escritura: casetas
create or replace function public.avi_house_save(
 p_clinic uuid,p_id uuid,p_version integer,p_data jsonb,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare r uuid;v public.aviculture_houses;v_name text;v_system text;v_capacity bigint;
 v_notes text;v_archived boolean;fp jsonb;
begin
 perform private.avi_guard(p_clinic,true,false);
 if p_data is null or jsonb_typeof(p_data) is distinct from 'object'
  or octet_length(p_data::text)>4000 then raise exception 'invalid_data';end if;
 v_name=private.avi_text(p_data,'name',80,true);
 v_system=btrim(coalesce(p_data->>'system',''));
 if v_system not in ('piso','jaula_bateria') then raise exception 'invalid_system';end if;
 v_capacity=private.avi_int(p_data,'capacity',0,1000000,0);
 v_notes=private.avi_text(p_data,'notes',1000,false);
 if coalesce(p_data->>'archived','false') not in ('true','false') then
  raise exception 'invalid_data';
 end if;
 v_archived=coalesce((p_data->>'archived')::boolean,false);
 fp=jsonb_build_object('kind','aviculture_house','id',p_id,'version',p_version,'data',p_data);
 r=private.vet_receipt(p_clinic,p_operation,fp);
 if r is not null then return r;end if;
 if p_id is null then
  insert into public.aviculture_houses(clinic_id,name,system,capacity_birds,notes,archived,created_by)
  values(p_clinic,v_name,v_system,v_capacity::int,v_notes,v_archived,auth.uid()) returning id into r;
  insert into public.audit_log(clinic_id,actor_id,action,entity_id)
  values(p_clinic,auth.uid(),'avi_house_created',r::text);
 else
  select * into v from public.aviculture_houses
   where clinic_id=p_clinic and id=p_id for update;
  if not found then raise exception 'not_found';end if;
  if v.version is distinct from p_version then raise exception 'version_conflict';end if;
  update public.aviculture_houses set name=v_name,system=v_system,
   capacity_birds=v_capacity::int,notes=v_notes,archived=v_archived,
   version=version+1,updated_at=clock_timestamp()
  where id=p_id and clinic_id=p_clinic returning id into r;
  insert into public.audit_log(clinic_id,actor_id,action,entity_id)
  values(p_clinic,auth.uid(),'avi_house_updated',r::text);
 end if;
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,fp,r);
 return r;
end$$;

-- 10. Escritura: parvadas
create or replace function public.avi_flock_save(
 p_clinic uuid,p_id uuid,p_version integer,p_data jsonb,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare r uuid;v public.aviculture_flocks;v_code text;v_house uuid;v_line text;
 v_start date;v_birds bigint;v_status text;v_notes text;fp jsonb;d date;tz text;
begin
 perform private.avi_guard(p_clinic,true,true);
 if p_data is null or jsonb_typeof(p_data) is distinct from 'object'
  or octet_length(p_data::text)>6000 then raise exception 'invalid_data';end if;
 select coalesce(timezone,'America/Mexico_City') into tz
  from public.inventory_clinic_settings where clinic_id=p_clinic;
 tz=coalesce(tz,'America/Mexico_City');
 d=(statement_timestamp() at time zone tz)::date;
 v_code=private.avi_text(p_data,'code',30,true);
 v_line=private.avi_text(p_data,'genetic_line',80,false);
 v_notes=private.avi_text(p_data,'notes',1000,false);
 if coalesce(p_data->>'start_date','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
  raise exception 'invalid_date';
 end if;
 begin v_start=(p_data->>'start_date')::date;exception when others then
  raise exception 'invalid_date';end;
 if v_start>d then raise exception 'invalid_date';end if;
 v_birds=private.avi_int(p_data,'initial_birds',1,1000000,0);
 if v_birds=0 then raise exception 'invalid_data';end if;
 if nullif(btrim(coalesce(p_data->>'house_id','')),'') is not null then
  begin v_house=(p_data->>'house_id')::uuid;exception when others then
   raise exception 'invalid_data';end;
  if not exists(select 1 from public.aviculture_houses h
   where h.clinic_id=p_clinic and h.id=v_house and not h.archived) then
   raise exception 'house_not_available';
  end if;
 else v_house=null;end if;
 v_status=coalesce(nullif(btrim(coalesce(p_data->>'status','')),''),'activa');
 if v_status not in ('activa','cerrada') then raise exception 'invalid_data';end if;
 fp=jsonb_build_object('kind','aviculture_flock','id',p_id,'version',p_version,'data',p_data);
 r=private.vet_receipt(p_clinic,p_operation,fp);
 if r is not null then return r;end if;
 if p_id is null then
  if exists(select 1 from public.aviculture_flocks where clinic_id=p_clinic and code=v_code) then
   raise exception 'flock_code_exists';
  end if;
  insert into public.aviculture_flocks(clinic_id,house_id,code,genetic_line,start_date,
   initial_birds,status,closed_on,notes,created_by)
  values(p_clinic,v_house,v_code,v_line,v_start,v_birds::int,v_status,
   case when v_status='cerrada' then greatest(d,v_start) end,v_notes,auth.uid())
  returning id into r;
  insert into public.audit_log(clinic_id,actor_id,action,entity_id)
  values(p_clinic,auth.uid(),'avi_flock_created',r::text);
 else
  select * into v from public.aviculture_flocks
   where clinic_id=p_clinic and id=p_id for update;
  if not found then raise exception 'not_found';end if;
  if v.version is distinct from p_version then raise exception 'version_conflict';end if;
  if v.initial_birds is distinct from v_birds::int and exists(
   select 1 from public.aviculture_production_records p
   where p.clinic_id=p_clinic and p.flock_id=p_id) then
   raise exception 'flock_has_records';
  end if;
  if v.code is distinct from v_code and exists(
   select 1 from public.aviculture_flocks where clinic_id=p_clinic and code=v_code
    and id<>p_id) then raise exception 'flock_code_exists';
  end if;
  update public.aviculture_flocks set house_id=v_house,code=v_code,genetic_line=v_line,
   start_date=v_start,initial_birds=v_birds::int,status=v_status,
   closed_on=case when v_status='cerrada' then coalesce(v.closed_on,greatest(d,v_start)) else null end,
   notes=v_notes,version=version+1,updated_at=clock_timestamp()
  where id=p_id and clinic_id=p_clinic returning id into r;
  insert into public.audit_log(clinic_id,actor_id,action,entity_id)
  values(p_clinic,auth.uid(),'avi_flock_updated',r::text);
 end if;
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,fp,r);
 return r;
end$$;

-- 11. Escritura: registro productivo diario
create or replace function public.avi_production_save(
 p_clinic uuid,p_id uuid,p_version integer,p_data jsonb,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare r uuid;v public.aviculture_production_records;f public.aviculture_flocks;
 v_flock uuid;v_date date;v_eggs bigint;v_discarded bigint;v_mortality bigint;
 v_feed numeric;v_weight numeric;v_water numeric;v_notes text;fp jsonb;
 v_birds bigint;v_other_mortality bigint;
begin
 perform private.avi_guard(p_clinic,true,false);
 if p_data is null or jsonb_typeof(p_data) is distinct from 'object'
  or octet_length(p_data::text)>6000 then raise exception 'invalid_data';end if;
 if coalesce(p_data->>'flock_id','')='' then raise exception 'flock_required';end if;
 begin v_flock=(p_data->>'flock_id')::uuid;exception when others then
  raise exception 'invalid_data';end;
 if coalesce(p_data->>'date','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
  raise exception 'invalid_date';
 end if;
 begin v_date=(p_data->>'date')::date;exception when others then
  raise exception 'invalid_date';end;
 v_eggs=private.avi_int(p_data,'eggs',0,5000000,0);
 v_discarded=private.avi_int(p_data,'eggs_discarded',0,5000000,0);
 v_mortality=private.avi_int(p_data,'mortality',0,1000000,0);
 v_feed=private.avi_num(p_data,'feed_kg',1000000,0);
 v_weight=private.avi_num(p_data,'avg_weight_g',20000,0);
 v_water=private.avi_num(p_data,'water_l',1000000,0);
 v_notes=private.avi_text(p_data,'notes',1000,false);
 fp=jsonb_build_object('kind','aviculture_production','id',p_id,'version',p_version,'data',p_data);
 r=private.vet_receipt(p_clinic,p_operation,fp);
 if r is not null then return r;end if;
 select * into f from public.aviculture_flocks
  where clinic_id=p_clinic and id=v_flock for update;
 if not found then raise exception 'not_found';end if;
 if f.status<>'activa' then raise exception 'flock_closed';end if;
 if v_date<f.start_date then raise exception 'invalid_date';end if;
 select coalesce(sum(p.mortality),0) into v_other_mortality
  from public.aviculture_production_records p
  where p.clinic_id=p_clinic and p.flock_id=v_flock and p.id is distinct from p_id;
 v_birds=f.initial_birds-v_other_mortality;
 if v_mortality>v_birds then raise exception 'mortality_exceeds_birds';end if;
 if p_id is null then
  if exists(select 1 from public.aviculture_production_records p
   where p.clinic_id=p_clinic and p.flock_id=v_flock and p.record_date=v_date) then
   raise exception 'record_exists';
  end if;
  insert into public.aviculture_production_records(clinic_id,flock_id,record_date,eggs,
   eggs_discarded,mortality,feed_kg,avg_weight_g,water_l,notes,recorded_by)
  values(p_clinic,v_flock,v_date,v_eggs::int,v_discarded::int,v_mortality::int,v_feed,
   nullif(v_weight,0),nullif(v_water,0),v_notes,auth.uid()) returning id into r;
  insert into public.audit_log(clinic_id,actor_id,action,entity_id)
  values(p_clinic,auth.uid(),'avi_production_created',r::text);
 else
  select * into v from public.aviculture_production_records
   where clinic_id=p_clinic and id=p_id for update;
  if not found or v.flock_id<>v_flock then raise exception 'not_found';end if;
  if v.version is distinct from p_version then raise exception 'version_conflict';end if;
  if exists(select 1 from public.aviculture_production_records p
   where p.clinic_id=p_clinic and p.flock_id=v_flock and p.record_date=v_date
    and p.id<>p_id) then raise exception 'record_exists';end if;
  update public.aviculture_production_records set record_date=v_date,eggs=v_eggs::int,
   eggs_discarded=v_discarded::int,mortality=v_mortality::int,feed_kg=v_feed,
   avg_weight_g=nullif(v_weight,0),water_l=nullif(v_water,0),notes=v_notes,
   version=version+1,updated_at=clock_timestamp()
  where id=p_id and clinic_id=p_clinic returning id into r;
  insert into public.audit_log(clinic_id,actor_id,action,entity_id)
  values(p_clinic,auth.uid(),'avi_production_updated',r::text);
 end if;
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,fp,r);
 return r;
end$$;

-- 12. Escritura: eventos sanitarios / de manejo
create or replace function public.avi_event_save(
 p_clinic uuid,p_id uuid,p_version integer,p_data jsonb,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $$
declare r uuid;v public.aviculture_flock_events;v_flock uuid;v_date date;v_kind text;
 v_title text;v_details text;v_withdrawal date;fp jsonb;f public.aviculture_flocks;
begin
 perform private.avi_guard(p_clinic,true,false);
 if p_data is null or jsonb_typeof(p_data) is distinct from 'object'
  or octet_length(p_data::text)>6000 then raise exception 'invalid_data';end if;
 begin v_flock=(p_data->>'flock_id')::uuid;exception when others then
  raise exception 'invalid_data';end;
 if coalesce(p_data->>'date','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
  raise exception 'invalid_date';
 end if;
 begin v_date=(p_data->>'date')::date;exception when others then
  raise exception 'invalid_date';end;
 v_kind=coalesce(nullif(btrim(coalesce(p_data->>'kind','')),''),'otro');
 if v_kind not in ('vacunacion','tratamiento','desparasitacion','pesaje',
  'alimentacion','inspeccion','otro') then raise exception 'invalid_kind';end if;
 v_title=private.avi_text(p_data,'title',120,true);
 v_details=private.avi_text(p_data,'details',2000,false);
 if nullif(btrim(coalesce(p_data->>'withdrawal_until','')),'') is not null then
  begin v_withdrawal=(p_data->>'withdrawal_until')::date;exception when others then
   raise exception 'invalid_date';end;
  if v_withdrawal<v_date then raise exception 'invalid_date';end if;
 else v_withdrawal=null;end if;
 fp=jsonb_build_object('kind','aviculture_event','id',p_id,'version',p_version,'data',p_data);
 r=private.vet_receipt(p_clinic,p_operation,fp);
 if r is not null then return r;end if;
 select * into f from public.aviculture_flocks
  where clinic_id=p_clinic and id=v_flock for update;
 if not found then raise exception 'not_found';end if;
 if v_date<f.start_date then raise exception 'invalid_date';end if;
 if p_id is null then
  insert into public.aviculture_flock_events(clinic_id,flock_id,event_date,kind,title,
   details,withdrawal_until,created_by)
  values(p_clinic,v_flock,v_date,v_kind,v_title,v_details,v_withdrawal,auth.uid())
  returning id into r;
  insert into public.audit_log(clinic_id,actor_id,action,entity_id)
  values(p_clinic,auth.uid(),'avi_event_created',r::text);
 else
  select * into v from public.aviculture_flock_events
   where clinic_id=p_clinic and id=p_id for update;
  if not found or v.flock_id<>v_flock then raise exception 'not_found';end if;
  if v.version is distinct from p_version then raise exception 'version_conflict';end if;
  update public.aviculture_flock_events set event_date=v_date,kind=v_kind,title=v_title,
   details=v_details,withdrawal_until=v_withdrawal,version=version+1
  where id=p_id and clinic_id=p_clinic returning id into r;
  insert into public.audit_log(clinic_id,actor_id,action,entity_id)
  values(p_clinic,auth.uid(),'avi_event_updated',r::text);
 end if;
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,fp,r);
 return r;
end$$;

revoke all on function public.avi_workspace(uuid),
 public.avi_house_save(uuid,uuid,integer,jsonb,text),
 public.avi_flock_save(uuid,uuid,integer,jsonb,text),
 public.avi_production_save(uuid,uuid,integer,jsonb,text),
 public.avi_event_save(uuid,uuid,integer,jsonb,text) from public,anon;
grant execute on function public.avi_workspace(uuid),
 public.avi_house_save(uuid,uuid,integer,jsonb,text),
 public.avi_flock_save(uuid,uuid,integer,jsonb,text),
 public.avi_production_save(uuid,uuid,integer,jsonb,text),
 public.avi_event_save(uuid,uuid,integer,jsonb,text) to authenticated;

notify pgrst,'reload schema';
commit;
