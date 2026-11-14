-- PROPUESTA, NO APLICADA. Agrega el tipo de cita 'visita_campo'.
--
-- Va en adaptations y no en proposed, aunque Sonnet pidiera un numero: la
-- restriccion que toca la define appointment_patient_search_v2.sql, que vive
-- aqui. La secuencia numerada de proposed es la del esquema nuevo, y ahi la
-- tabla de citas ni siquiera tiene estos tipos; numerarlo la haria parecer
-- parte de una linea que no es la suya.
--
-- Depende de appointment_patient_search_v2.sql: se aplica DESPUES de ella.
-- La lista de abajo es la suya, palabra por palabra, mas 'visita_campo'.
-- Comprobado contra el archivo, no supuesto: si esa lista cambia antes de
-- aplicar esto, hay que volver a copiarla o este alter borra los tipos que
-- falten.
--
-- ORDEN DE PUBLICACION: esto va ANTES que la app que ofrece la opcion. Al
-- reves, quien elija «Visita a campo o granja» recibe un rechazo del
-- servidor al guardar la cita.

begin;

alter table public.clinic_appointments
  drop constraint if exists clinic_appointments_kind_check;
alter table public.clinic_appointments
  add constraint clinic_appointments_kind_check
  check (kind in ('consulta','seguimiento','estetica','cirugia','analisis',
                  'hospital_visita','vacunacion','entrega','visita_campo','otro'));

notify pgrst, 'reload schema';

commit;
