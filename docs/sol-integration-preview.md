# Integración preliminar Sol 6 / 6.1 + clínica visual y Ajustes

Esta rama es **una PREVIEW DE DIAGNÓSTICO**, no una versión apta para uso clínico ni una beta firmada.
Base visual y personalización: `rojasalex9615-blip/Vetdosis-pruebAS@95219eb7e23ef07694789d31e7388ba988cc2415`.
Fuentes trasladadas de Sol: `rojasalex9615-blip/Vet-dosis-pruebas@b64ff80ca84bff29977f747c6052848da5103ad6`.

Incluye propuestas SQL/test y utilidades para respaldos de PostgreSQL y Storage, funciones servidor para avisos hospitalarios, registro de destinos Firebase con consentimiento explícito y liquidación de comisiones por servicio, conectada de modo independiente de las comisiones periódicas.

**Limitaciones**:
- No aplica SQL ni despliega Edge Functions, ni configura cron o proveedores de WhatsApp.
- El envío externo solo es operativo cuando Firebase tiene configuración beta válida, el personal da consentimiento, y el RPC/proveedor están instalados en **Pruebas**. La alarma local nunca debe depender de FCM.
- Las comisiones por acto y por periodo son modelos diferentes: no ejecutar liquidaciones cruzadas sin verificar políticas contables y migraciones.
- La APK de este workflow es debug. Nunca sobrescribe ni publica builds beta firmadas.
- La consolidación del flujo completo de respaldos y servicios requiere comprobar las migraciones remotas en Pruebas, el catálogo real y pruebas de dos clínicas.
- El icono y las pantallas visuales pertenecen a la base del nuevo repositorio; no sustituir su carpeta `android/mipmap` con la anterior.
- Revisar CODE RABBIT y CI antes de marcar completo.

Identidad/procedencia se guarda en BUILD-SOURCES.json del artefacto.
