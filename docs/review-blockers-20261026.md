# Correcciones propuestas a las revisiones de #28 y #35

Base: PR #37, `3bd2d633d721819099dc9106a3b9628c7aa81a98`.
Rama: `fix/integration-review-blockers-20261026`.
No es aprobación de CodeRabbit ni QA integral de dos clínicas.

## Corregido en esta propuesta

- #35 Major: acciones de la preview fijadas por commit SHA; checkout no
  conserva credenciales Git. Otros workflows conservan su configuración.
- #35 Major: configuración local de hospital-delivery permite llegar al
  chequeo de HOSPITAL_DISPATCH_SECRET, que se valida antes de crear el cliente
  privilegiado. Compara hashes de longitud fija con timingSafeEqual. No activa
  proveedores ni despliega funciones.
- #28: la recarga explícita tras guardar conserva preferencias cargadas ante
  fallo y propaga el error al mensaje de la pantalla. Primera carga y cambio
  de identidad siguen descartando preferencias anteriores.
- #28: la prueba de visibilidad de IA usa un repositorio real simulado y un
  control positivo; ya no pasa simplemente por omitir la dependencia ai.
- #35: pruebas FCM comprueban proyecto, token de destino, payload y ausencia
  de patient/paciente.

## Ya incorporado en la base consolidada

- #28: mínimo iOS 15.5, búsqueda manual normalizada y pruebas de navegación
  adaptadas a IA en cabecera/OCR y Ayuda en menú.
- #35: run_restore acepta storage_object_keys y compara PostgreSQL/Storage;
  mounted antes de recarga de comisiones y checksums relativos al artefacto.

## Verificación local

- Flutter analyze sin incidencias.
- 13 pruebas de preferencias y 15 de navegación aprobadas.
- 6 pruebas Node de transporte/autenticación aprobadas.
- Deno check del entrypoint aprobado, dependencias fijadas en deno.lock.
- Handler Deno local con secreto sintético: sin credencial y credencial
  incorrecta devuelven 401; correcta sin proveedores devuelve 503; GET 405.
- No se contactaron proveedores reales ni bases remotas para estas pruebas.

## Pendientes de #35 y revisión

Revalidar rotación FCM entre clínicas, estado external_delivery_enabled en el
workspace, caché del token FCM, revocación de destinos de otros usuarios,
leases agotadas y asignación determinista por canal en pruebas SQL.
Los hilos originales permanecen abiertos: una corrección en rama derivada no
acredita su resolución ni una revisión completa del conjunto. Pendientes QA
con dos clínicas, entrega real, restauración real y APK beta firmada aprobada.
