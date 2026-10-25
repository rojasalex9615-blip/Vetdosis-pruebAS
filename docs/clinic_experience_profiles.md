# Perfiles de clínica y flujos configurables (candidato beta)

Rama independiente sobre la integración visual/clínica PR #26. La instalación SQL remota queda pendiente; ni las pruebas locales ni un APK acreditan disponibilidad del RPC en producción.

## Contratos
- Perfil general, pequeñas especies, hospital, producción o personalizado.
- Secciones y submódulos configurables por clínica. Ajustes, recuperación y herramientas de revisión autorizadas **no** se pueden ocultar por personalización.
- Configuración sincronizada en servidor mediante RPC versionado, lectura por miembros, escritura por **administrador** y control optimista de revisión. No se guardan claves de IA en estas preferencias.
- La visibilidad es una intersección: **permiso de servidor ∧ preferencia de visualización**. La configuración nunca concede permisos ni altera las políticas RLS/roles. Apagar secciones tampoco borra registros, cancela alarmas ni deshabilita transacciones pendientes.
- Preferencia de proveedor de IA preselecciona únicamente una conexión ya listada/autorizada. Se puede cambiar antes de enviar; el usuario sigue aceptando cada envío.
- Canales de hospitalización elegibles por clínica: **teléfono** (alarma/notificación nativa, NO llamada ni SMS), **WhatsApp** o **ambos**. Valor seguro inicial: teléfono. La elección es informativa hasta que exista backend WhatsApp operativo; jamás desactiva por sí sola alarmas locales ni los avisos críticos. El trabajador mantiene controles locales de sonido, vibración y anticipación por dispositivo.
- WhatsApp exige conexión institucional verificada, identidad/membresía y turno vigente, permiso de hospitalización, número autorizado y consentimiento documentado por destinatario. Solo mensajes mínimos del tipo «Hay una tarea de hospitalización en VetDosis; abre la app». No transmitir nombres, diagnósticos, medicación ni datos del dueño por defecto. Registrar idempotencia, estado de entrega, reintentos y escalamiento sin duplicar órdenes. Despliegue del transporte corresponde al trabajo de Codex/6.1; **este PR no modifica alertas ni credenciales de WhatsApp**.
- La preferencia de clínica **no sustituye** las preferencias particulares del personal ni puede ocultar urgencias. En una clínica con dos usuarios, el envío depende además de opt-in individual y derechos vigentes al momento de envío.

- Flujos libre, asistido, obligatorio por tarea. Esta versión **almacena** el modo, pero **no lo aplica como política clínica obligatoria** hasta vincular contexto de paciente, acciones y RPC de cada proceso. Ninguna opción omite revisión de dosis, autorización MVZ, medicamentos regulados, trazabilidad u otros controles actuales.
- El perfil y los flujos no implican disponibilidad de funciones de producción o interfaces futuras; módulos pendientes mantienen su estado pendiente.

## Despliegue y pruebas pendientes
1. Revisar prerequisitos \`public.clinics\`, \`public.clinic_members\`, \`private.has_clinic_role\`, y compatibilidad con SQL de integración, incluyendo rol personal.
2. Aplicar una migración versionada a **Pruebas**; el archivo \`supabase/proposed/14J_clinic_experience.sql\` es candidato, no desplegado ni una entrada de migración definitiva.
3. Validar HTTP/RPC con dos clínicas, dos administradores concurrentes, auxiliares, sesiones anónimas y cambios de membresía; verificar control de revisiones y listas desconocidas.
4. Pruebas de widget y navegación: cambiar de clínica limpia inmediatamente preferencias; Ajustes continúa visible; cambios de perfil ocultan rutas sin conceder derechos; al no existir RPC mostrar secciones habituales sin simular guardados.
5. Implementar guías y transiciones obligatorias **por proceso** en cliente y servidor con pruebas de acceso directo, cambios de permisos durante la operación y excepciones clínicas antes de marcar el modo obligatorio como operativo.
6. Validación en APK Android y revisión por integración (no fusionar ramas clínicas sin resolver CI).
7. Canales hospitalización: simular teléfono, WhatsApp y ambos; ausencia de proveedor, número sin consentimiento, turno revocado, cambio de clínica, desactivación de notificaciones del sistema y fallos de red. No enviar por WhatsApp desde esta configuración; exigir backend auditado.
8. Actualizar el candidato SQL en la rama: admite `hospital_notice_delivery` y conserva el default `phone`. La base Pruebas todavía no lo tiene aplicado hasta validación y despliegue explícito.

## Criterios de seguridad
Administración del workspace es independiente del criterio MVZ; admins eligen la apariencia pero no pueden forzar el bypass de comprobaciones clínicas. El proveedor de IA es un identificador público, jamás una API key. Las claves reales se gestionan en el gateway seguro existente.
