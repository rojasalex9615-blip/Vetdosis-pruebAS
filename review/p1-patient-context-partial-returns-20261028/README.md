# P1 — selección de paciente y devolución parcial

Rama `fix/p1-patient-context-partial-returns-20261028`. Base #63 `e246f230051f46f8cfda40debfcdc743c6fbfc1e`, con las tres observaciones de su primera revisión atendidas. No main ni despliegues. La base P0 y esta entrega requieren sus revisiones; una prueba local no las fusiona ni instala.

## Refresco de autenticación sin perder el paciente

Hallazgo #61: `chooseDosePatient` comparaba `AuthViewModel.accessRevision` con el contador al abrir la ruta. El contador cambia en cada refresh, incluso cuando usuario/clínica/rol permanecen iguales. Con el refresco de 30 segundos, se descartaba la búsqueda y el cálculo dejaba de abrirse.

La ruta ahora conserva un contexto de acceso propio durante la selección y la revisión de peso. No modifica el contador global ni el refresco de autenticación. Comprueba en vivo usuario real de la sesión, clínica, rol, membresía y estado online; vuelve a consultar el contrato de módulos durante los refrescos y antes de validar el peso/calcular o volver a indicaciones. No depende del `moduleAccess` capturado en una instancia antigua de CoreShell.

Una comprobación pendiente en segundo plano conserva el último acceso ya comprobado para no borrar la selección durante un refresco normal. Una respuesta de revocación, error o contrato mal formado la invalida. Un resultado antiguo no puede restaurar acceso tras una comprobación posterior. Cambios reales de identidad/clínica/rol/offline invalidan inmediatamente, sin esperar al RPC. Sin repositorio de módulos configurado se conserva el modo legado anterior; esto no añade permisos al servidor.

La revalidación antes de calcular sigue comprobando el peso persistido, su origen y el ingreso hospitalario. Los RPC continúan autorizando cada operación. No se crean recetas ni tratamientos automáticamente.

Pruebas nuevas:

- App y CoreShell reales con temporizador de 30 segundos: conserva texto/paciente y abre la calculadora con peso registrado después del refresco.
- Revocación confirmada de módulo hospitalario borra nombres del selector.
- Usuario, clínica, rol, membresía y offline invalidan el contexto.
- Error, esquema desconocido, respuesta tardía, contexto inicial sin verificar y disposición durante una solicitud no conceden acceso.

## Devoluciones: atravesar el repositorio real

Hallazgo #61: la pantalla llamaba `inv_sale_return_v3`, pero faltaba en `SupabaseInventoryRepository.writes`; se rechazaba localmente antes de contactar al servidor. Los fakes de pantalla anteriores no ejercitaban esta lista.

Se añadió únicamente ese RPC. La prueba nueva conecta pantalla → repositorio Supabase real → cliente PostgREST → transporte HTTP simulado. Comprueba endpoint POST, actor, venta, turno, cantidad, acumulado previo, importe, reembolso, ajuste de comisión, ausencia de restock por defecto e identidad de operación. La pantalla solo cierra después de la respuesta exitosa.

Otros tests confirman propagación de 403 y contrato ausente (404), y que operaciones no permitidas siguen bloqueadas antes del transporte. No se cambiaron cálculo de importes, doble confirmación ni permisos SQL. El transporte simulado no acredita autenticación ni RLS reales.

## Compatibilidad y verificación

52 pruebas focalizadas aprobadas: selección/peso, peso comercial/persistido, devoluciones, abonos y nuevo repositorio real. `flutter analyze --no-pub` limpio. El runner `run_financial_return_freshness.sh` pasó en PostgreSQL efímero sin red, incluidas carreras de reintegros, devoluciones y abonos. Batería Flutter completa: **685 aprobadas, 1 omitida**, sin fallos. Código probado: `bc48f644cddb2596d57e9d015123d8b4506f3400`.

Nueva CI `validate-p1-patient-return.yml`: las mismas regresiones focalizadas, análisis y SQL financiero, con acciones fijadas por SHA, checkout sin credenciales persistidas y sin secretos/despliegue.

Reproducción:

```sh
flutter pub get
flutter analyze --no-pub
flutter test --no-pub test/hospital_calculation_refresh_test.dart test/hospital_dose_patient_test.dart test/hospital_weight_test.dart test/recorded_weight_calculation_test.dart test/commercial_recorded_weight_test.dart test/partial_return_supabase_test.dart test/partial_product_return_test.dart test/installments_service_returns_test.dart
bash supabase/tests/run_financial_return_freshness.sh
flutter test --no-pub
```

## P0 de base y límites

Antes de este frente se atendieron las tres observaciones de #63: orden de bloqueos clinic→member (con deadlock del orden antiguo reproducido), detección de referencias `secrets` por índice y path de CI del scanner. Ocho Python y SQL combinado financiero/personal/carreras aprobados. El seguimiento posterior de #63 bloquea también el contexto secrets completo y añade todos los tests P0 al filtro de CI. Seguimiento en #63 y documentación P0.

La lectura de catálogo de Supabase Pruebas en esta entrega está en `remote-contracts.json`. Solo consulta existencia de funciones y privilegio anónimo, sin datos clínicos ni escrituras. El cliente corregido no instala contratos faltantes. No declarar devoluciones operativas de extremo a extremo si faltan workspace/v3, ni dar por verificado el cuerpo/RLS de una función por existir.

Otros hallazgos de #26/#61 continúan pendientes (herramientas manuales, etiquetas de fluidoterapia, leases, Drive y otros); #20 legal sigue fuera de esta rama. No se incorporó la rama ajena de integración Drive/Sol. CodeRabbit debe revisar esta entrega; no equivale a revisión favorable de toda la base.

Sin cambios a main, SQL remoto, secretos, deploy ni APK nueva. Persisten QA HTTP con dos clínicas, revisión de contratos/migraciones y QA real Android antes de distribución.
