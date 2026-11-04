-- Standalone non-transactional step. Do not wrap in BEGIN or psql --single-transaction.
CREATE INDEX CONCURRENTLY vial_movement_chronology ON public.medication_vial_movements(clinic_id,vial_id,created_at);
