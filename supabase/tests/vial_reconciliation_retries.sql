create function pg_temp.vial_assert(v boolean,msg text) returns void language plpgsql as $$begin if v is distinct from true then raise exception 'ASSERT: %',msg;end if;end$$;
create function pg_temp.vial_error(sql text,expected text) returns void language plpgsql as $$begin begin execute sql;exception when others then if position(expected in sqlerrm)>0 then return;end if;raise;end;raise exception 'Expected rejection: %',expected;end$$;
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
select id as product from public.medication_product_versions where product_key='synthetic-permission-liquid' \gset
select id as case_id from public.clinical_cases where title='Synthetic medication case' \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000151',false);
set role authenticated;
select public.rx_vial_open(:'clinic',:'product','SYNTHETIC-RETRY','10',to_char(clock_timestamp()-interval '1 minute','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),null,null,repeat('da01',12)) as vial \gset
select public.rx_vial_close(:'vial','10','',repeat('da02',12)) as closure \gset
reset role;
select to_jsonb(r) as frozen from public.medication_vial_reconciliations r where id=:'closure' \gset
-- A later application must still be reportable as an incident, not silently discarded.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
select id as procedure from private.procedure_types where clinic_id=:'clinic' and name='Synthetic medication care' \gset
set role authenticated;
select public.permission_grant(:'clinic','00000000-0000-0000-0000-000000000152','vial.draw',:'procedure',clock_timestamp()+interval '1 day','Synthetic retry draw authority');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000152',false);
set role authenticated;
select public.rx_medication_report(:'case_id',jsonb_build_object('product_version_id',:'product','quantity','2','unit','ml','route','synthetic route','procedure','cuidados','performed_by',auth.uid(),'observed_at',to_char(clock_timestamp(),'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'vial_id',:'vial'),repeat('da03',12)) as late_report \gset
reset role;
select pg_temp.vial_assert(private.rx_vial_balance(:'vial')=8,'later application lost from physical ledger');
select pg_temp.vial_assert((select incidence like '%Frasco cerrado%' from public.medication_records where id=:'late_report'),'late application lost its incident');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000151',false);
set role authenticated;
select pg_temp.vial_assert(public.rx_vial_close(:'vial','10','',repeat('da02',12))=:'closure'::uuid,'retry recomputed discrepancy and lost original receipt');
select pg_temp.vial_error(format('select public.rx_vial_close(%L,%L,%L,%L)',:'vial','8','',repeat('da04',12)),'vial_already_closed');
select pg_temp.vial_error(format('select public.rx_vial_close(%L,%L,%L,%L)',:'vial','8','',repeat('da02',12)),'operation_payload_changed');
reset role;
select pg_temp.vial_assert((select count(*)=1 from public.medication_vial_reconciliations where vial_id=:'vial'),'second closure created');
select pg_temp.vial_assert((select to_jsonb(r)=:'frozen'::jsonb from public.medication_vial_reconciliations r where id=:'closure'),'frozen closure changed');
select pg_temp.vial_assert(not has_function_privilege('anon','public.rx_vial_close(uuid,text,text,text)','EXECUTE'),'anonymous closure permitted');
-- Returning a known receipt must still revalidate current authority.
select id as manage_grant from private.member_permission_grants where clinic_id=:'clinic' and user_id='00000000-0000-0000-0000-000000000151' and code='vial.manage' limit 1 \gset
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
select public.permission_revoke(:'manage_grant','Synthetic retry authority revoked');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000151',false);
set role authenticated;
select pg_temp.vial_error(format('select public.rx_vial_close(%L,%L,%L,%L)',:'vial','10','',repeat('da02',12)),'explicit_permission_required');
reset role;
