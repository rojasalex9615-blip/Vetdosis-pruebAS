-- Apply after 13B5. Supports foreign-key checks on the new settlement ledger.
begin;
create index if not exists clinic_service_commission_settlements_sale
 on public.clinic_service_commission_settlements(clinic_id,sale_id);
create index if not exists clinic_service_commission_settlements_professional
 on public.clinic_service_commission_settlements(professional_id);
create index if not exists clinic_service_commission_settlements_recorder
 on public.clinic_service_commission_settlements(recorded_by);
commit;
