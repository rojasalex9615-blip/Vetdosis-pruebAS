# Mi espacio personal (16A)

Encargo de Ale (2026-11-12): en «Mi cuenta» había dos «Mi espacio personal» y el
que parecía el espacio personal solo cambiaba de área de trabajo (terminaba en
Inicio o en Producción). El espacio personal debía tener notas, recordatorios,
horarios de una o más clínicas y una ficha de emergencia que la persona decide
compartir, con registro de accesos para ella y para el encargado de la clínica.

## Qué había

- `personal_workspace_create` crea un **área de trabajo** que el servidor llama
  «Mi espacio personal». En «Mi cuenta» aparecía dos veces: el botón «Abrir mi
  espacio personal» y la fila del área. Ajustes → «Mi cuenta y clínicas» abría
  además la pantalla de alta, con un tercer «Usar mi espacio personal».
- La ficha de emergencia ya existía por clínica (`staff_medical`, migración
  20261027142748): consentimiento versionado, consulta solo de administradores
  con permiso `staff.medical.read`, finalidad obligatoria y registro de accesos
  sin contenido médico.

## Qué cambia

Aplicación:

- «Mi cuenta» muestra **una** tarjeta «Mi espacio personal» que abre una
  pantalla propia (no cambia la clínica activa). El área de trabajo se nombra
  «Área de trabajo personal» y el botón para crearla solo aparece si no existe.
- Ajustes → «Mi cuenta y clínicas» abre la pantalla de cuenta, no la de alta.
- Pantalla «Mi espacio personal» con pestañas Notas, Recordatorios, Horarios y
  Emergencia. Emergencia lista las clínicas y abre la ficha de cada una.
- Ficha: campo nuevo «Fármacos a los que soy alérgico/a»; «Enfermedades o
  padecimientos (opcional)»; panel para elegir compañeros, ver las fichas que
  me compartieron y el registro de accesos con nombres.

Servidor (`supabase/proposed/16A_espacio_personal.sql`, **no aplicado**):

- `personal_notes` y `personal_work_schedules`, RLS solo del dueño.
- Aviso de ficha versión 2: dice que también consultan los compañeros elegidos.
  Las fichas guardadas con el aviso 1 dejan de verse hasta que su dueño acepte
  el aviso 2 (en Pruebas hay 0 fichas).
- `drug_allergies` admitido en `ops_staff_medical_write`.
- `private.staff_medical_delegates` y las funciones `ops_staff_medical_delegates`,
  `ops_staff_medical_delegate_set`, `ops_staff_medical_delegate_view` y
  `ops_staff_medical_access_log` (el dueño ve los accesos a su ficha; la
  administración de la clínica ve todos). La purga borra también las elecciones.

## Pruebas

- `supabase/tests/personal_space.sql` (runner `run_personal_space.sh`): pasó en
  PostgreSQL 16 local con la cadena completa de `run_permission_clinic_operations.sh`.
  `staff_medical_privacy.sql` va antes de 16A porque fija el aviso 1.
- `test/personal_space_test.dart`; suite completa 834 aprobadas, 1 omitida;
  `flutter analyze` sin hallazgos (Flutter 3.47.6).

## Límites y siguiente acción

- Sin 16A en el servidor la app sigue funcionando: notas/horarios muestran que
  requieren actualización y la ficha usa la lista de accesos anterior.
- Los recordatorios no lanzan notificación del teléfono todavía.
- Pendiente: autorización de Ale para aplicar 16A en Pruebas, revisión de
  CodeRabbit y prueba en teléfono. No se actualizó el tablón #31 (otro
  repositorio, fuera del alcance de esta sesión).
