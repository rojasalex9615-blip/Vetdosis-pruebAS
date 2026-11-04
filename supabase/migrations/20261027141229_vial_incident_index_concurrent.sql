-- Standalone non-transactional step. Do not wrap in BEGIN or psql --single-transaction.
CREATE INDEX CONCURRENTLY vial_record_incidents ON public.medication_records(clinic_id,vial_id,reported_at desc,id) WHERE incidence<>'';
