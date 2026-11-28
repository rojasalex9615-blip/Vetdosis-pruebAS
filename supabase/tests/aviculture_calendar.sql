-- Solo base aislada: fixtures sintéticos, nunca datos reales.
\ir aviculture_farms_health.sql
\ir ../proposed/23_aviculture_calendar.sql
\ir ../proposed/23_aviculture_calendar.sql
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
do $$declare c uuid='10000000-0000-0000-0000-000000000001';h uuid;f uuid;x uuid;y uuid;d jsonb;r jsonb;before_count integer;begin
 select id into h from public.aviculture_houses where clinic_id=c and farm_id is not null order by id limit 1;
 select count(*) into before_count from public.aviculture_health_events where clinic_id=c;
 d=jsonb_build_object('house_id',h,'date',current_date+7,'kind','vacunacion','title','Tarea capturada','days_before',3);
 x=public.avi_calendar_save(c,null,null,d,repeat('a2',24));
 y=public.avi_calendar_save(c,null,null,d,repeat('a2',24));if x<>y then raise exception 'calendar_retry';end if;
 perform public.test_avi_denied(format('select public.avi_calendar_save(%L,null,null,%L,%L)',c,(d||'{"title":"Otra tarea"}')::text,repeat('a2',24)),'operation_payload_changed');
 perform public.test_avi_denied(format('select public.avi_calendar_save(%L,%L,99,%L,%L)',c,x,d::text,repeat('b2',24)),'version_conflict');
 perform public.test_avi_denied(format('select public.avi_calendar_save(%L,null,null,%L,%L)',c,(d||'{"days_before":91}')::text,repeat('b2',24)),'invalid_data');
 perform public.avi_calendar_save(c,x,1,d||'{"status":"completada"}',repeat('b2',24));
 if (select count(*) from public.aviculture_health_events where clinic_id=c)<>before_count then raise exception 'calendar_created_applied_event';end if;
 r=public.avi_calendar_workspace(c);
 if jsonb_array_length(r->'items')<>1 or r#>>'{items,0,status}'<>'completada' then raise exception 'calendar_status';end if;
 r=private.clinic_snapshot(c)::jsonb;
 if jsonb_array_length(r#>'{tables,aviculture_schedule}')<>1 then raise exception 'calendar_backup';end if;
 if r#>>'{tables,original,0,exact}'<>'12345678901234567890.123' then raise exception 'original_snapshot';end if;
 if(select count(*) from public.audit_log where clinic_id=c and action='avi_calendar_saved' and entity_id=x::text)<>2 then raise exception 'calendar_audit';end if;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',false);
do $$declare c uuid='10000000-0000-0000-0000-000000000001';h uuid;begin
 select id into h from public.aviculture_houses where clinic_id=c and farm_id is not null limit 1;
 perform public.avi_calendar_save(c,null,null,jsonb_build_object('house_id',h,'date',current_date+1,'kind','seguimiento','title','Revisión del equipo'),repeat('c2',24));
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',false);
select public.test_avi_denied($q$select public.avi_calendar_workspace('10000000-0000-0000-0000-000000000001')$q$,'access_denied');
set role authenticated;
select public.test_avi_denied('select * from public.aviculture_schedule','permission denied for table aviculture_schedule');
reset role;
do $$begin
 if has_function_privilege('anon','public.avi_calendar_workspace(uuid)','execute') then raise exception 'calendar_anon';end if;
 if has_function_privilege('authenticated','private.clinic_snapshot_before_avi_calendar(uuid)','execute') then raise exception 'calendar_snapshot_exposed';end if;
end$$;
