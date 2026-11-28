set timezone='America/Mexico_City';
-- PostgreSQL aislado: NO ejecutar contra datos reales; crea fixtures de M15.
\ir aviculture_postura.sql
-- Snapshot sintético anterior: conserva sus datos y su autorización.
create or replace function private.clinic_snapshot(p_clinic uuid) returns text
language plpgsql security definer set search_path='' as $$begin
 if not exists(select 1 from public.clinic_members where clinic_id=p_clinic and user_id=auth.uid() and role='admin') then raise exception 'admin_required';end if;
 return jsonb_build_object('version',1,'clinic_id',p_clinic,'tables',jsonb_build_object('original',jsonb_build_array(jsonb_build_object('exact',12345678901234567890.123))))::text;
end$$;
\ir ../proposed/22_aviculture_farms_health.sql
\ir ../proposed/22_aviculture_farms_health.sql
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
do $$declare c uuid='10000000-0000-0000-0000-000000000001';a uuid;b uuid;h uuid;j uuid;f uuid;x uuid;y uuid;r jsonb;d jsonb;begin
 a=public.avi_farm_save(c,null,null,'{"name":"Norte"}',repeat('a0',24));
 if a<>public.avi_farm_save(c,null,null,'{"name":"Norte"}',repeat('a0',24)) then raise exception 'retry_farm';end if;
 perform public.test_avi_denied(format('select public.avi_farm_save(%L,null,null,%L,%L)',c,'{"name":"Cambio"}',repeat('a0',24)),'operation_payload_changed');
 b=public.avi_farm_save(c,null,null,'{"name":"Sur"}',repeat('b0',24));
 h=public.avi_farm_house_save(c,a,null,null,'{"name":"Caseta 1","system":"piso","capacity":1000}',repeat('c0',24));
 j=public.avi_farm_house_save(c,b,null,null,'{"name":"Caseta 1","system":"piso","capacity":1000}',repeat('d0',24));
 if h=j then raise exception 'houses_not_distinct';end if;
 perform public.test_avi_denied(format('select public.avi_farm_save(%L,%L,99,%L,%L)',c,a,'{"name":"Norte"}',repeat('e0',24)),'version_conflict');
 perform public.test_avi_denied(format('select public.avi_farm_save(%L,%L,1,%L,%L)',c,a,'{"name":"Norte","archived":true}',repeat('e0',24)),'farm_has_active_houses');
 f=public.avi_flock_save(c,null,null,jsonb_build_object('code','N-1','house_id',h,'initial_birds',100,'start_date',current_date-10),repeat('f0',24));
 d=jsonb_build_object('house_id',h,'flock_id',f,'date',current_date-2,'kind','vacunacion','product','Producto capturado','dose','Dosis capturada','route','Vía capturada');
 x=public.avi_health_event_save(c,d,repeat('10',24));
 y=public.avi_health_event_save(c,d,repeat('10',24));
 if x<>y then raise exception 'retry_health';end if;
 if (select count(*) from public.audit_log where clinic_id=c and action='avi_health_recorded' and entity_id=x::text)<>1 then raise exception 'audit_health';end if;
 perform public.test_avi_denied(format('select public.avi_health_event_save(%L,%L,%L)',c,(d||jsonb_build_object('house_id',j))::text,repeat('20',24)),'flock_not_in_house');
 perform public.test_avi_denied(format('select public.avi_health_event_save(%L,%L,%L)',c,(d||jsonb_build_object('date',current_date+1))::text,repeat('20',24)),'invalid_date');
 perform public.test_avi_denied(format('select public.avi_farm_house_save(%L,%L,%L,1,%L,%L)',c,b,h,'{"name":"Caseta trasladada","system":"piso","capacity":1000}',repeat('20',24)),'house_has_history');
 perform public.avi_health_event_save(c,jsonb_build_object('house_id',h,'date',current_date,'kind','enfermedad','diagnosis','Hallazgo observado','status','observada'),repeat('30',24));
 r=public.avi_farms_workspace(c);
 if jsonb_array_length(r->'farms')<>2 or jsonb_array_length(r->'health')<>2 or r->>'can_manage'<>'true' then raise exception 'workspace';end if;
 r=private.clinic_snapshot(c)::jsonb;
 if r#>>'{tables,original,0,exact}'<>'12345678901234567890.123' then raise exception 'snapshot_original';end if;
 if jsonb_array_length(r#>'{tables,aviculture_farms}')<>2 or jsonb_array_length(r#>'{tables,aviculture_health_events}')<>2 then raise exception 'snapshot_poultry';end if;
 if exists(select 1 from jsonb_array_elements(r#>'{tables,aviculture_houses}') item where item->>'clinic_id'<>c::text) then raise exception 'snapshot_scope';end if;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',false);
do $$declare c uuid='10000000-0000-0000-0000-000000000001';h uuid;r jsonb;begin
 r=public.avi_farms_workspace(c);
 if r->>'can_manage'<>'false' then raise exception 'aux_permissions';end if;
 perform public.test_avi_denied(format('select public.avi_farm_save(%L,null,null,%L,%L)',c,'{"name":"Sin permiso"}',repeat('40',24)),'lead_role_required');
 select id into h from public.aviculture_houses where clinic_id=c and farm_id is not null limit 1;
 perform public.avi_health_event_save(c,jsonb_build_object('house_id',h,'date',current_date,'kind','medicacion','product','Tratamiento registrado'),repeat('40',24));
 perform public.test_avi_denied(format('select private.clinic_snapshot(%L)',c),'admin_required');
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',false);
select public.test_avi_denied($q$select public.avi_farms_workspace('10000000-0000-0000-0000-000000000001')$q$,'access_denied');
set role authenticated;
select public.test_avi_denied('select * from public.aviculture_farms','permission denied for table aviculture_farms');
select public.test_avi_denied('select * from public.aviculture_health_events','permission denied for table aviculture_health_events');
reset role;
do $$begin
 if has_function_privilege('anon','public.avi_farms_workspace(uuid)','execute') then raise exception 'anon_workspace';end if;
 if has_function_privilege('authenticated','private.clinic_snapshot_before_avi_farms(uuid)','execute') then raise exception 'private_snapshot_exposed';end if;
end$$;
