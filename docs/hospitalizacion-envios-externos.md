# Avisos hospitalarios por FCM y WhatsApp — preparación 14J/14K/14L

Estado en Supabase Pruebas al 25 de octubre de 2026: migración 14J instalada;
función `hospital-delivery` versión 1 desplegada y llamada sin secreto rechazada
con HTTP 401. Hay cero destinos y cero entregas; `external_delivery_enabled`
sigue en `false`. El generador de órdenes 14G sí está habilitado y el trabajo
por minuto corrió sin fallos; el reparto por turnos permanece apagado. Las
credenciales de Firebase/Meta y la programación de la función de envíos aún no
están configuradas. La migración 14K agrega consulta y revocación de destinos
propios, más rotación del token por dispositivo. Está instalada en Supabase de
pruebas. El proyecto Firebase beta `vetdosis-pro-155db` y su archivo Android
están incorporados en la rama de la PR 29; falta integrar y probar el APK.

La migración `supabase/proposed/14J_hospital_external_delivery.sql` agrega
destinos consentidos por integrante, una entrega por aviso/canal y una cola
privada. Se instala después de 14G, con `external_delivery_enabled=false`.
No concede permisos ni activa envíos. La función `hospital-delivery` acepta solo
un secreto de despacho del servidor; usa el rol de servicio para reclamar lotes.
Al encender el transporte se fija la hora de activación; avisos anteriores no se
despachan retroactivamente.

Cada reclamación vuelve a comprobar la membresía, permisos hospitalarios,
designación MVZ cuando corresponde, consentimiento, tarea pendiente, estancia
activa y ausencia de respuesta. Un destino revocado no vuelve a reclamarse.
La cola conserva intentos, resultado y referencia del proveedor; reintenta con
espera progresiva hasta ocho intentos. La función nunca envía nombre del
paciente, indicación, dosis ni detalles de la tarea: FCM muestra un aviso
genérico; WhatsApp usa una plantilla `es_MX` aprobada y sin variables clínicas.
Abrir la app y responder el aviso sigue siendo distinto de realizar el cuidado.

## Configuración pendiente antes de activar

1. Crear el proyecto Firebase de la beta, registrar la app Android con su
   identificador `io.github.alexcore123r.vetdosis.beta` y descargar
   `google-services.json`. FCM no exige SHA-1 para avisos básicos. Configurar
   recepción, permiso de notificaciones y token FCM en Flutter. La PR 29 agrega
   consentimiento explícito, registro y revocación por dispositivo; requiere
   un APK nuevo y una sesión clínica real para comprobarlo. Guía oficial:
   <https://firebase.google.com/docs/flutter/setup> y
   <https://firebase.google.com/docs/cloud-messaging/flutter/get-started>.
2. Crear la cuenta de WhatsApp Business Cloud API, número remitente y plantilla
   `hospital_alert` en `es_MX` (o el nombre finalmente aprobado), categoría
   Utility, sin variables clínicas. Texto propuesto: «Tienes un aviso de
   hospitalización pendiente. Abre VetDosis Pro para revisarlo. Recibir este
   aviso no confirma que se haya realizado el cuidado». Confirmar consentimiento
   y titularidad del número de cada integrante, y ofrecer revocación visible.
   El número temporal de Meta sirve para pruebas con destinatarios autorizados;
   para entrega real se necesita un número empresarial y el estado comercial
   exigido por Meta. Guía oficial:
   <https://developers.facebook.com/documentation/business-messaging/whatsapp/get-started>.
3. Guardar en secretos de Supabase Edge Functions:
   `HOSPITAL_DISPATCH_SECRET`, `HOSPITAL_FCM_PROJECT_ID`,
   `HOSPITAL_FCM_CLIENT_EMAIL`, `HOSPITAL_FCM_PRIVATE_KEY`,
   `HOSPITAL_WHATSAPP_ACCESS_TOKEN`, `HOSPITAL_WHATSAPP_PHONE_NUMBER_ID`,
   `HOSPITAL_WHATSAPP_TEMPLATE`, `HOSPITAL_WHATSAPP_GRAPH_VERSION`.
   Para FCM, crear una cuenta de servicio dedicada con permiso de envío FCM
   HTTP v1; usar de su JSON `project_id`, `client_email` y `private_key`.
   Para Meta, usar un token duradero de usuario de sistema con permiso
   `whatsapp_business_messaging`, no el token temporal de inicio rápido.
   No colocar estas claves en Flutter, GitHub, capturas ni documentos.
4. La migración 14L permite que el despachador reclame únicamente los canales
   con credenciales completas. FCM puede configurarse y probarse sin WhatsApp;
   los avisos de WhatsApp permanecen en espera sin consumir reintentos.
   Desplegar `hospital-delivery`; programar su invocación por minuto mediante
   Supabase Cron/`pg_net`, usando un secreto guardado en Vault. Comprobar
   permisos de invocación, errores y reintentos. No compartir el rol de servicio
   con el programador ni con el teléfono.
5. Activar `external_delivery_enabled` solo cuando al menos FCM esté
   configurado, los destinatarios sean correctos y se haya retirado cualquier
   alarma local duplicada que compita con este recorrido. La generación 14G
   (`enabled`) y el reparto por turnos (`duty_routing_enabled`) son interruptores
   independientes.

Una confirmación HTTP del proveedor acredita aceptación de la solicitud, no
lectura por la persona ni realización del cuidado. Un corte entre el envío y el
registro del resultado puede ocasionar un reintento duplicado. Falta mostrar
estado de entrega y ejecutar el recorrido real con la app cerrada antes de
encender los interruptores. La PR 29 ya presenta destinos propios y revocación.

Ale ya proporcionó `google-services.json` para la app Android beta. Para
continuar con WhatsApp basta indicar el ID del número remitente y el
nombre/idioma de la plantilla aprobada; los tokens y claves privadas se
capturan directamente en los secretos del servicio y nunca se envían por chat.
