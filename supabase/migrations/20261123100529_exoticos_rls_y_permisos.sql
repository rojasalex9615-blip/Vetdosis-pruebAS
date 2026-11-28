-- RLS igual que el resto del proyecto: authenticated SOLO lee, y lee unicamente
-- lo de su clinica. Las escrituras no tienen politica a proposito, para que
-- solo puedan entrar por los RPC SECURITY DEFINER.

alter table public.exotic_enclosures enable row level security;
alter table public.exotic_enclosure_readings enable row level security;
alter table public.exotic_identifiers enable row level security;
alter table public.exotic_legal_status enable row level security;
alter table public.exotic_feedings enable row level security;
alter table public.exotic_clutches enable row level security;
alter table public.exotic_events enable row level security;
alter table public.exotic_quarantine_plans enable row level security;

-- Los recintos no son dato de un paciente: basta pertenecer a la clinica,
-- igual que en las tablas de produccion.
create policy exotic_enclosures_read on public.exotic_enclosures
  for select using (private.has_clinic_role(clinic_id));
create policy exotic_readings_read on public.exotic_enclosure_readings
  for select using (private.has_clinic_role(clinic_id));
create policy exotic_clutches_read on public.exotic_clutches
  for select using (private.has_clinic_role(clinic_id));

-- Lo que cuelga de un ejemplar es expediente clinico: se abre con el mismo
-- permiso que vet_patients, no con la simple pertenencia a la clinica.
create policy exotic_identifiers_read on public.exotic_identifiers
  for select using (private.permission_patient_read(clinic_id));
create policy exotic_legal_read on public.exotic_legal_status
  for select using (private.permission_patient_read(clinic_id));
create policy exotic_feedings_read on public.exotic_feedings
  for select using (private.permission_patient_read(clinic_id));
create policy exotic_events_read on public.exotic_events
  for select using (private.permission_patient_read(clinic_id));

-- La cuarentena es dato de hospitalizacion: mismo permiso que hospital_stays.
create policy exotic_quarantine_read on public.exotic_quarantine_plans
  for select using (private.hospital_readable(clinic_id));

-- Concesiones: authenticated solo SELECT. Sin INSERT/UPDATE/DELETE.
grant select on public.exotic_enclosures to authenticated;
grant select on public.exotic_enclosure_readings to authenticated;
grant select on public.exotic_identifiers to authenticated;
grant select on public.exotic_legal_status to authenticated;
grant select on public.exotic_feedings to authenticated;
grant select on public.exotic_clutches to authenticated;
grant select on public.exotic_events to authenticated;
grant select on public.exotic_quarantine_plans to authenticated;
