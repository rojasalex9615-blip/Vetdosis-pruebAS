# Pequeñas especies: orden de aplicación y estado real en Supabase

Fecha de comprobación: **2026-11-11**. Proyecto **Pruebas**
`wtrelwtztkddfktrfdpb`, PostgreSQL 17.11.0.003. La comprobación fue de solo
lectura: `pg_proc`, `pg_class`, `pg_constraint` y conteos agregados. No se
ejecutó DDL, no se leyó ningún registro clínico ni de cuenta, y no se aplicó
nada.

## Corrección a lo que dije antes

En el mensaje anterior conté `supabase/migrations` (11 archivos) contra
`supabase/proposed` (73) y concluí que «todo lo clínico está diseñado pero no
desplegado». **Eso era falso.** La carpeta `migrations` no es el inventario de
lo instalado: la base de Pruebas se actualizó por paquetes incrementales, el
último documentado en `review/supabase-missing-contracts-20261028/`. Contra el
servidor, de los **83 archivos** de la cadena de pequeñas especies hay **79
aplicados y 4 pendientes**, más la adaptación de la visita a campo, que va
fuera de esa cadena.

## Lo que falta aplicar

| Archivo | Qué habilita | Riesgo de no aplicarlo |
|---|---|---|
| `supabase/proposed/13X_storage_media.sql` | Fotos de paciente y adjuntos clínicos | La pantalla ofrece subir y el servidor rechaza |
| `supabase/proposed/13Y_ai_key_rotation.sql` | Rotación de la llave del asistente | La llave no se puede rotar sin tocar la base a mano |
| `supabase/proposed/15M_lab_results.sql` | Analíticas de laboratorio en el expediente | El botón del expediente falla al abrir |
| `supabase/proposed/15N_lab_reference_library_bridge.sql` | Que el laboratorio del expediente lea la biblioteca ya instalada | Sin él, 15M marca «Sin rango de referencia» en todos los analitos |
| `supabase/adaptations/appointment_kind_field_visit_v1.sql` | Tipo de cita «Visita a campo o granja» | **Va antes de publicar la app**: al revés, la cita se rechaza al guardar |

Verificado uno por uno: `private.storage_patient_photo_allowed`,
`private.storage_clinical_attachment_allowed`, `public.ai_key_rotate_server`,
`private.ai_capture_credential_version`, `public.lab_workspace` y
`private.lab_reference_for` no existen en el servidor. La restricción
`clinic_appointments_kind_check` que hay instalada es, palabra por palabra, la
que copia el archivo de la visita a campo, **menos** `'visita_campo'`: el
`alter` no borrará ningún tipo en uso.

`15N` depende de `15M`; `appointment_kind_field_visit_v1` depende de
`appointment_patient_search_v2`, que ya está aplicada. Los otros tres son
independientes entre sí.

## Valores de referencia: sí existen y sí se ven

La biblioteca está instalada y cargada en Pruebas, en el esquema de
preparación `vetdosis_reference_staging`:

| Qué | Filas |
|---|---:|
| Filas importadas en total | 2 574 |
| Resuelven como referencia de **laboratorio** | 403 |
| Resuelven como **constantes fisiológicas** | 301 |
| Canino · laboratorio | 113 |
| Felino · laboratorio | 103 |
| Canino / Felino · constantes | 13 / 11 |
| Productos comerciales con etiqueta | 1 384 (531 regímenes) |

Se leen desde **Calculadora → «Referencias fisiológicas»** y
**«Referencias de laboratorio»**, por `public.reference_review_list`, que ya
está instalada. El acceso exige rol `admin` o `mvz` en la clínica y permiso
`clinical.read`.

Tres cosas que la clínica revisora debe saber antes de abrir la app:

1. **Ninguna fila está validada.** Las 2 574 están en `review_state =
   'pending'`, con la nota «Imported verbatim; not clinically validated». La
   pantalla lo muestra como pendiente de validación MVZ. Eso es precisamente
   lo que se les pide revisar.
2. **Las fuentes son de la importación, no un libro de texto.** En canino y
   felino las que más aparecen son `labforvets.com` y `riomartinez.com`. Cada
   intervalo viaja con su fuente a la vista para que se pueda aceptar,
   corregir o rechazar.
3. **Donde dos fuentes no coinciden se muestran las dos.** Es la regla que
   fijó Ale, y está en el dominio (`readings()` / `agreedFlag()`), no en el
   servidor: el servidor no emite ningún veredicto, y una prueba lo fija
   (`not (... ? 'flag')`). Cuando el archivo de origen avisa de otro intervalo
   sin darlo, el aviso viaja dentro de la fuente y **no** se inventa un
   segundo rango.

Hay dos casos ya contrastados a mano en `reference_display_decisions`
(temperatura rectal de perro y de gato, contra el Merck Veterinary Manual),
marcados «fuente contrastada, pendiente de MVZ».

## El hueco que esto cierra

`15M` creaba `private.lab_reference_ranges` vacía a propósito y la pantalla del
expediente leía solo de ahí. Efecto práctico: el laboratorio del expediente
habría marcado «Sin rango de referencia» en **todos** los analitos, aunque el
servidor ya tuviera 216 valores de canino y felino. `15N` hace que esa lectura
use la biblioteca, sin copiar nada y sin marcar nada como verificado.

`15N` cambia además una cosa a propósito: `15M` filtraba los rangos por unidad
dentro del SQL, así que un rango publicado en otra unidad desaparecía y el
resultado salía como «sin rango». Ahora llegan todos y el cliente distingue
«otra unidad» de «sin referencia». Para el veterinario la diferencia importa:
lo primero se corrige, lo segundo no.

Se añade `public.lab_analyte_catalog(clínica, paciente)`: la captura ofrece los
nombres que la biblioteca conoce para la especie **del expediente** (la especie
la lee el servidor, no la manda el cliente) y al elegir uno llena la unidad.
Sin eso el analito se teclea libre y una letra de más deja el resultado sin
referencia para siempre, sin aviso al guardar.

## Orden completo de los 83 archivos

Derivado de la cadena de runners del repositorio (`run_small_animal_integration.sh`
y las 87 cadenas de `supabase/tests/`), por orden topológico de las
restricciones que esas cadenas imponen. No es un orden inventado: es el que el
repositorio ya ejercita en CI. Las cuatro filas marcadas «sonda compartida»
comparten la función de prueba con otro archivo, así que su estado se infiere
del conjunto y no por sí solas.

| # | Archivo | Estado en Pruebas |
|---:|---|---|
| 1 | `supabase/proposed/10_identity.sql` | aplicado |
| 2 | `supabase/proposed/13B3_service_categories.sql` | aplicado (sonda compartida) |
| 3 | `supabase/proposed/09A_beta_foundation.sql` | aplicado |
| 4 | `supabase/proposed/09B_beta_gate.sql` | aplicado |
| 5 | `supabase/proposed/11A_permission_foundation.sql` | aplicado |
| 6 | `supabase/proposed/12A_terms_acceptances.sql` | aplicado |
| 7 | `supabase/proposed/12B_platform_professional_admin.sql` | aplicado |
| 8 | `supabase/proposed/12C_privacy_binding.sql` | aplicado |
| 9 | `supabase/proposed/13A_permission_patient_registration.sql` | aplicado |
| 10 | `supabase/proposed/13B_permission_agenda.sql` | aplicado |
| 11 | `supabase/proposed/13C_permission_clinical.sql` | aplicado |
| 12 | `supabase/proposed/13D_hospital_flexible_admission.sql` | aplicado |
| 13 | `supabase/proposed/13E_permission_hospital_reviews.sql` | aplicado |
| 14 | `supabase/proposed/13F_permission_medication.sql` | aplicado |
| 15 | `supabase/proposed/13G_permission_hospital_resolution.sql` | aplicado |
| 16 | `supabase/proposed/13H1_consultation_attestation.sql` | aplicado |
| 17 | `supabase/proposed/13H2_prescription_individual.sql` | aplicado |
| 18 | `supabase/proposed/13H3_standing_prescriptions.sql` | aplicado |
| 19 | `supabase/proposed/13I1_permission_dispensing.sql` | aplicado |
| 20 | `supabase/proposed/13I2_permission_inventory_cash.sql` | aplicado |
| 21 | `supabase/proposed/13J1_permission_reports.sql` | aplicado |
| 22 | `supabase/proposed/13J2_permission_form_templates.sql` | aplicado |
| 23 | `supabase/proposed/13J3_form_document_drafts.sql` | aplicado |
| 24 | `supabase/proposed/13J4_form_individual_workflow.sql` | aplicado |
| 25 | `supabase/proposed/13K_clinical_screen_contract.sql` | aplicado |
| 26 | `supabase/proposed/13L_independent_clinical_cases.sql` | aplicado |
| 27 | `supabase/proposed/13M_death_attestation.sql` | aplicado |
| 28 | `supabase/proposed/13N_module_navigation_dashboard.sql` | aplicado |
| 29 | `supabase/proposed/13O_permission_backups_exports.sql` | aplicado |
| 30 | `supabase/proposed/13P_workspace_management_cutover.sql` | aplicado |
| 31 | `supabase/proposed/13B1_permission_clinic_operations.sql` | aplicado |
| 32 | `supabase/proposed/13B2_restore_module_navigation.sql` | aplicado |
| 33 | `supabase/proposed/13B4_service_subcategories.sql` | aplicado (sonda compartida) |
| 34 | `supabase/proposed/13B5_service_commission_settlements.sql` | aplicado |
| 35 | `supabase/proposed/13B6_service_commission_fk_indexes.sql` | aplicado |
| 36 | `supabase/proposed/13Y_ai_key_rotation.sql` | PENDIENTE |
| 37 | `supabase/migrations/20261027021257_service_commission_recoveries.sql` | aplicado |
| 38 | `supabase/migrations/20261027024532_partial_product_returns.sql` | aplicado |
| 39 | `supabase/proposed/14D_admin_service_commissions.sql` | aplicado (sonda compartida) |
| 40 | `supabase/proposed/14F_catalog_service_sale_price.sql` | aplicado |
| 41 | `supabase/migrations/20261027031218_installments_service_returns.sql` | aplicado |
| 42 | `supabase/migrations/20261027144905_financial_return_freshness.sql` | aplicado |
| 43 | `supabase/migrations/20261027142748_staff_medical_consent_access.sql` | aplicado |
| 44 | `supabase/proposed/13W_clinical_vitals.sql` | aplicado |
| 45 | `supabase/proposed/13X_storage_media.sql` | PENDIENTE |
| 46 | `supabase/proposed/14D_hospital_isolation.sql` | aplicado |
| 47 | `supabase/proposed/14E_clinical_rapid_tests.sql` | aplicado |
| 48 | `supabase/proposed/14E_commission_payroll.sql` | aplicado |
| 49 | `supabase/proposed/14F_hospital_care_results.sql` | aplicado |
| 50 | `supabase/proposed/14G_hospital_automation.sql` | aplicado |
| 51 | `supabase/proposed/14G_sale_invoice_requests.sql` | aplicado |
| 52 | `supabase/proposed/14H_supplier_directory.sql` | aplicado (sonda compartida) |
| 53 | `supabase/proposed/14H_team_duty.sql` | aplicado |
| 54 | `supabase/proposed/14I_clinic_contact_directory.sql` | aplicado |
| 55 | `supabase/proposed/14I_hospital_history.sql` | aplicado |
| 56 | `supabase/proposed/14J_clients_promotions.sql` | aplicado |
| 57 | `supabase/proposed/14J_hospital_external_delivery.sql` | aplicado |
| 58 | `supabase/proposed/14K_client_loyalty.sql` | aplicado |
| 59 | `supabase/proposed/14K_hospital_push_targets.sql` | aplicado |
| 60 | `supabase/proposed/14L_clinic_productivity.sql` | aplicado |
| 61 | `supabase/proposed/14L_hospital_delivery_channels.sql` | aplicado |
| 62 | `supabase/proposed/14J_clinic_experience.sql` | aplicado |
| 63 | `supabase/proposed/14M_ai_assisted_workflows.sql` | aplicado |
| 64 | `supabase/proposed/14N_week_plan_tasks.sql` | aplicado |
| 65 | `supabase/proposed/14O_team_communications.sql` | aplicado |
| 66 | `supabase/proposed/15M_lab_results.sql` | PENDIENTE |
| 67 | `supabase/proposed/15N_lab_reference_library_bridge.sql` | PENDIENTE |
| 68 | `supabase/migrations/20261027062933_vial_reconciliation_retries.sql` | aplicado |
| 69 | `supabase/migrations/20261027064618_vial_incident_overview.sql` | aplicado |
| 70 | `supabase/migrations/20261027141227_vial_movement_index_concurrent.sql` | aplicado |
| 71 | `supabase/migrations/20261027141229_vial_incident_index_concurrent.sql` | aplicado |
| 72 | `supabase/adaptations/patient_contacts_appointment_links_v1.sql` | aplicado |
| 73 | `supabase/adaptations/appointment_care_v1.sql` | aplicado |
| 74 | `supabase/adaptations/patient_activity_snapshot_v1.sql` | aplicado |
| 75 | `supabase/adaptations/preventive_booklet_v2.sql` | aplicado |
| 76 | `supabase/adaptations/appointment_patient_search_v2.sql` | aplicado |
| 77 | `supabase/proposed/13Q_restore_preview_staging.sql` | aplicado |
| 78 | `supabase/proposed/13R_restore_conflict_preview.sql` | aplicado |
| 79 | `supabase/proposed/13S_restore_decision_preview.sql` | aplicado |
| 80 | `supabase/proposed/13T_restore_application_preflight.sql` | aplicado |
| 81 | `supabase/proposed/13U_restore_owners_apply.sql` | aplicado |
| 82 | `supabase/proposed/13V_restore_patients_apply.sql` | aplicado |
| 83 | `supabase/migrations/20261028043154_preserve_member_history.sql` | aplicado |

## Ya aplicado

`aplicacion-20261111.md` registra que los cinco archivos pendientes **se
aplicaron en Pruebas el 11/11**, con autorización de Ale, y la comprobación
posterior objeto por objeto. Las tablas de pendientes de este README y del mapa
describen el estado **anterior** a esa aplicación.

## Mapa de arquitectura

`mapa-arquitectura-20261111.md` actualiza la matriz de estados del *Master
Control Document* con lo verificado aquí, y corrige tres nombres de contrato que
ese documento daba y que no existen en el servidor (`get_user_clinics`,
`process_pos_sale`, `close_cash_shift`).

## Qué queda fuera de este alcance

- **No apliqué nada.** Los cinco archivos pendientes esperan autorización
  explícita de Ale, proyecto por proyecto.
- **No validé ningún valor de referencia.** No soy quien para firmar un
  intervalo clínico; por eso el trabajo fue dejar que se vean con su fuente.
- **No pude correr `flutter analyze` ni las pruebas de widget**: este contenedor
  no trae el SDK de Flutter. Eso lo resuelve CI en el PR.
- Las unidades de la importación vienen como en el archivo de origen
  (`uL` para cuentas absolutas, `10^6/uL` para eritrocitos). No las normalicé:
  cambiarlas es una decisión de la revisión, no mía.
