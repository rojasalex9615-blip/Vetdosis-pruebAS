-- Mismo modelo que el resto del proyecto: authenticated SOLO lee. Las
-- escrituras no tienen politica a proposito, para que solo entren por los RPC
-- SECURITY DEFINER.

alter table public.reproduccion_gestaciones enable row level security;
alter table public.reproduccion_gestacion_dias enable row level security;

-- Una gestacion cuelga de un paciente, asi que es expediente clinico: se abre
-- con el mismo permiso que vet_patients, no con la simple pertenencia a la
-- clinica. Es el mismo criterio que exotic_feedings o exotic_events.
create policy reproduccion_gestaciones_read on public.reproduccion_gestaciones
  for select using (private.permission_patient_read(clinic_id));

-- El catalogo de dias es referencia publica para cualquiera con sesion: no
-- dice nada de ninguna clinica.
create policy reproduccion_gestacion_dias_read on public.reproduccion_gestacion_dias
  for select using (true);

grant select on public.reproduccion_gestaciones to authenticated;
grant select on public.reproduccion_gestacion_dias to authenticated;
