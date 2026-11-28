# Activación del calendario e integración visual — 28 nov 2026

Se habilitó el calendario sanitario en el proyecto Supabase **Pruebas** (`wtrelwtztkddfktrfdpb`), con autorización expresa de Ale en esta conversación. No se aplicaron cambios a otros proyectos.

| Versión remota | Migración | Fuente del repositorio |
|---|---|---|
| 20261128082523 | enable_aviculture_m15_records | supabase/adaptations/existing_aviculture_m15.sql |
| 20261128082546 | enable_aviculture_farms_health | supabase/proposed/22_aviculture_farms_health.sql |
| 20261128082558 | enable_aviculture_sanitary_calendar | supabase/proposed/23_aviculture_calendar.sql |

M15 no estaba instalado y se aplicó antes de sus dependencias 22/23. Se habilitaron granjas, casetas, parvadas, registros productivos y sanitarios y programación compartida. Los parámetros de referencia de clase conservan su estado `sin_verificar`; los parámetros sin fuente permanecen pendientes. No se agregaron granjas, pacientes ni tareas de ejemplo persistentes.

Verificación remota: todas las tablas avícolas tienen RLS, sin acceso directo para anon/authenticated; los 11 RPC públicos requieren autenticación y verifican pertenencia a clínica y rol, con search_path vacío. Se comprobó crear granja/caseta/tarea, consultar, completar, incluir calendario en el snapshot de clínica y rechazar otra clínica, en una transacción revertida al terminar. Completar una tarea no crea una aplicación de vacuna/medicamento en la bitácora. Las tablas operativas quedaron vacías después de la prueba.

Se comparó el asesor de seguridad antes/después: no aparecieron nuevas vistas SECURITY DEFINER ni funciones con search_path mutable ni acceso anónimo. El patrón RPC añade 11 avisos de funciones SECURITY DEFINER autenticadas y 9 informativos de RLS sin políticas; es intencional: tablas sin acceso directo, guardas en RPC y funciones internas privadas. Los hallazgos preexistentes ajenos a esta activación requieren revisión separada; no se declara una auditoría global limpia. [Documentación de privilegios de funciones](https://supabase.com/docs/guides/database/functions#function-privileges).

La programación y sus avisos se consultan dentro de la app; no se añadieron notificaciones nativas. Incluir tablas en el respaldo no implementa su restauración operativa completa.

## Integración de código

Rama `integracion/calendario-iconos-20261128`: reúne los PR #153–#157 y la base #145, e incorpora la beta vigente `70b98a0` (PR #149). Se preservan las mejoras recientes de Caja, vademécum y chat de la beta. Las dos historias comparten ancestro; no se mezcló el main antiguo.

Cabeceras con franja: icono plano en tinta oscura en claro y tinta legible en oscuro, sin recuadro. Los módulos de Inicio y los recuadros del menú lateral comparten VetIconBox: placa tintada con halo de color y sin sombras neu. La tarjeta exterior conserva su relieve. Las siguientes comprobaciones visuales usan VetDosisApp completo y las fuentes reales; los datos sintéticos siguen limitados al arnés local.

El workflow del APK firmado usa APP_CHANNEL=beta también al compilar una rama de integración: conserva el control de versiones beta, el encabezado del build y el retorno OAuth de Android. Análisis local: 0 errores, 0 advertencias y 336 infos por APIs deprecadas del SDK local. Pruebas de firma/configuración: 9 pasan y 1 omitida por la herramienta externa de Android; publicación: 6 pasan. Suite Flutter completa en curso. Integración y compilación pendientes de las verificaciones del commit final. El estado de esta nota sustituye el pendiente de habilitación 22/23 del informe anterior.
