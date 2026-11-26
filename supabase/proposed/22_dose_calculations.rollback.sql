-- Deshace la migración 22 (cálculos de dosis en la ficha). Solo elimina
-- objetos que creó ella.
begin;
drop function if exists public.vet_dose_calculations_for_patient(uuid,uuid,integer);
drop function if exists public.record_vet_dose_calculation(uuid,uuid,jsonb,text);
drop table if exists public.vet_dose_calculations;
commit;
