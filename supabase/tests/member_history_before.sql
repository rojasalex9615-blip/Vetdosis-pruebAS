-- Synthetic regression setup. Public removal fails BEFORE the correction.
select id as clinic from public.clinics where name='Synthetic medication permissions' \gset
insert into auth.users(id,email,email_confirmed_at) values
 ('00000000-0000-0000-0000-000000000290','p0-former-staff@example.test',now()),
 ('00000000-0000-0000-0000-000000000291','p0-outsider@example.test',now());
insert into public.clinic_members(clinic_id,user_id,role) values(:'clinic','00000000-0000-0000-0000-000000000290','auxiliar');
insert into private.member_job_labels(clinic_id,user_id,label,updated_by)
 values(:'clinic','00000000-0000-0000-0000-000000000290','Synthetic retained label','00000000-0000-0000-0000-000000000150');
insert into public.clinic_staff_contacts(clinic_id,user_id,phone) values(:'clinic','00000000-0000-0000-0000-000000000290','000000');
insert into public.staff_medical_profiles(clinic_id,user_id,details) values(:'clinic','00000000-0000-0000-0000-000000000290','{"synthetic":true}');
insert into public.attendance_consents(clinic_id,user_id,settings_version) values(:'clinic','00000000-0000-0000-0000-000000000290',1);
insert into public.attendance_events(clinic_id,user_id,direction,distance_m,accuracy_m,qr_bucket) values(:'clinic','00000000-0000-0000-0000-000000000290','entrada',1,1,123);
insert into public.clinic_private_messages(clinic_id,author_id,recipient_id,body) values
 (:'clinic','00000000-0000-0000-0000-000000000150','00000000-0000-0000-0000-000000000290','Synthetic received history'),
 (:'clinic','00000000-0000-0000-0000-000000000290','00000000-0000-0000-0000-000000000150','Synthetic sent history');
insert into public.clinic_tasks(clinic_id,title,assigned_to,priority,created_by) values(:'clinic','Synthetic former assignment','00000000-0000-0000-0000-000000000290','media','00000000-0000-0000-0000-000000000150');
insert into public.clinic_appointments(clinic_id,patient_name,species,kind,professional_id,starts_at,ends_at,created_by)
 values(:'clinic','Synthetic patient','synthetic','estetica','00000000-0000-0000-0000-000000000290',now(),now()+interval '1 hour','00000000-0000-0000-0000-000000000150');
select id as service from public.clinic_services where clinic_id=:'clinic' limit 1 \gset
insert into public.clinic_service_acts(clinic_id,service_id,professional_id,name,service_version,price,commission,commission_kind,commission_value,created_by)
 values(:'clinic',:'service','00000000-0000-0000-0000-000000000290','Synthetic historical act',1,100,10,'bono',10,'00000000-0000-0000-0000-000000000150') returning id as act \gset
select id as shift from public.inventory_cash_shifts where clinic_id=:'clinic' limit 1 \gset
insert into public.inventory_sales(clinic_id,shift_id,cashier_id,method,total,cost,commission,created_at)
 values(:'clinic',:'shift','00000000-0000-0000-0000-000000000150','efectivo',100,0,10,now()-interval '3 days') returning id as sale \gset
insert into public.inventory_sale_lines(sale_id,clinic_id,kind,name,quantity,price,cost,total,commission,professional_id,metadata,service_act_id)
 values(:'sale',:'clinic','servicio','Synthetic historical earnings',1,100,0,100,10,'00000000-0000-0000-0000-000000000290','{}',:'act');
insert into public.clinic_commission_schedule(clinic_id,cadence,pay_day,period_start,next_pay_on,updated_by)
 values(:'clinic','semanal',1,now()-interval '4 days',(now() at time zone private.inv_timezone(:'clinic'))::date-1,'00000000-0000-0000-0000-000000000150');
insert into public.clinic_commission_payments(clinic_id,professional_id,period_start,period_end,scheduled_on,amount,recorded_by)
 values(:'clinic','00000000-0000-0000-0000-000000000290',now()-interval '5 days',now()-interval '4 days',current_date-4,3,'00000000-0000-0000-0000-000000000150');
-- Compare entire frozen history, not only row counts.
create table private.p0_history_fingerprints(relation_name text primary key,digest text not null);
do $snapshot$
declare relation_name text; digest text;
begin
 foreach relation_name in array array[
  'public.vet_patients','public.clinical_cases','public.prescriptions',
  'public.clinic_appointments','public.clinic_tasks','public.clinic_service_acts',
  'public.clinic_staff_contacts','public.clinic_private_messages',
  'public.staff_medical_profiles','public.attendance_consents','public.attendance_events',
  'public.clinic_commission_payments','public.inventory_sales','public.inventory_sale_lines',
  'private.member_job_labels'
 ] loop
  execute format('select md5(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text)::text,''[]'')) from %s t',relation_name) into digest;
  insert into private.p0_history_fingerprints values(relation_name,digest);
 end loop;
end
$snapshot$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000150',false);
set role authenticated;
do $reproduce$
declare clinic uuid;
begin
 select id into clinic from public.clinics where name='Synthetic medication permissions';
 begin
  perform public.remove_clinic_member(clinic,'00000000-0000-0000-0000-000000000290');
 exception when foreign_key_violation then
  raise notice 'Reproduced historical membership FK blocking removal';return;
 end;
 raise exception 'Regression setup did not reproduce blocked removal';
end
$reproduce$;
reset role;
