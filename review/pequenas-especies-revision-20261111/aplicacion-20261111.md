# Aplicación en Supabase Pruebas — 11 de noviembre de 2026

**Autorizado por Ale** («permisos, tienen todos, por parte mía»). Proyecto
**Pruebas** `wtrelwtztkddfktrfdpb`, PostgreSQL 17.11.0.003. Cada archivo entró
en su propia transacción, con el mismo texto que está en el repositorio.

| # | Archivo | Resultado |
|---:|---|---|
| 1 | `supabase/proposed/13X_storage_media.sql` | aplicado |
| 2 | `supabase/proposed/15M_lab_results.sql` | aplicado |
| 3 | `supabase/proposed/15N_lab_reference_library_bridge.sql` | aplicado |
| 4 | `supabase/adaptations/appointment_kind_field_visit_v1.sql` | aplicado |
| 5 | `supabase/proposed/13Y_ai_key_rotation.sql` | aplicado |

## Comprobación posterior, objeto por objeto

Las 14 sondas en OK:

- **13X**: `private.storage_safe_uuid`, `storage_patient_photo_allowed`,
  `storage_clinical_attachment_allowed`; **8 políticas** sobre
  `storage.objects`; **2 buckets** privados (`patient-photos` 8 MB,
  `clinical-attachments` 20 MB); permiso `clinical.attach` en el catálogo.
- **15M**: tablas `private.lab_reference_ranges`, `lab_panels`, `lab_results`
  con RLS, sus índices y los dos disparadores de inmutabilidad; funciones
  `public.lab_workspace`, `lab_panel_record`, `lab_result_correct`.
  `private.beta_install_guards()` no devolvió ninguna objeción.
- **15N**: `private.lab_reference_for`, `public.lab_analyte_catalog`, y
  `lab_workspace` reemplazada para resolver los rangos desde la biblioteca.
- **Visita a campo**: `clinic_appointments_kind_check` ya admite
  `'visita_campo'`, conservando los nueve tipos anteriores.
- **13Y**: `public.ai_key_rotate_server`,
  `private.ai_capture_credential_version` con su disparador, la columna
  `public.ai_requests.credential_version` y `ai_finish_server` reemplazada.

## Que los rangos aparecen, comprobado con datos reales

```
private.lab_reference_for('Hematocrito','Canino')
  → 37–55 %, fuente «labforvets.com · pendiente de validación MVZ», verified false
private.lab_reference_for('Creatinina','Canino')   → 2 fuentes
private.lab_reference_for('Albúmina','Felino')     → 2 fuentes
```

Eso era el objetivo: el expediente ya no va a decir «Sin rango de referencia»
en todos los analitos, y donde hay dos fuentes llegan las dos, cada una con su
procedencia y marcada como pendiente de validación MVZ.

## Asesores de seguridad después de aplicar

Cuatro avisos en todo el proyecto, y ninguno nuevo por esto:

- `rls_enabled_no_policy` (INFO) — toca las tablas de laboratorio y **es el
  diseño**: RLS activo y todos los permisos revocados, para que no exista
  ninguna vía que no pase por una función que comprueba permisos.
- `authenticated_security_definer_function_executable` (WARN) — las cuatro
  funciones del laboratorio, igual que las otras 334 del proyecto: comprueban
  el permiso por dentro con `permission_require`.
- `anon_security_definer_function_executable` (WARN) — **una sola función** en
  todo el esquema `public` es ejecutable sin sesión: `beta_request_guard`, que
  tiene que serlo para el registro de la beta cerrada. Comprobado con
  `has_function_privilege('anon', …)`. Ninguna función de hoy la toca.
- `auth_leaked_password_protection` (WARN) — ajuste de Auth, ajeno a esto.

## Lo que sigue sin estar hecho

- **Nadie lo ha probado en un teléfono.** Es el siguiente paso y es de Ale.
- **Ningún valor de referencia está validado**: las 2 574 filas siguen en
  `review_state = 'pending'`. Eso es el trabajo de la clínica revisora.
- El APK de GitHub seguirá en rojo: pide cuatro secretos de firma de Android
  que no están disponibles. GitLab no los necesita.
