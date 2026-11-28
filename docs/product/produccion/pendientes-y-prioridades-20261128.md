# Producción: organización y revisión de pendientes

Continuación del PR #155, sobre #154 (crianza, guías y sanidad), #153 y #145. Se revisaron todas las especies del catálogo. Esta entrega completa funciones que pueden operar con los registros, modelos y fórmulas disponibles; no declara completos los protocolos ni parámetros que siguen sin fuente validada.

## Implementado

- Navegación por **Registros, Calculadoras y Referencias**, con especie y actividad visibles. Los registros persistentes y las referencias porcinas ya no se mezclan con formularios de cálculo. Los planes de bandas guardados van en Registros. La biblioteca mantiene sus permisos y rutas a módulos reales.
- Búsqueda por nombre/objetivo dentro del apartado actual, sin distinguir acentos ni mayúsculas. Favoritos locales por usuario y área de trabajo, separados de otras cuentas. El filtro muestra favoritos de la actividad actual y solo herramientas disponibles con los permisos vigentes. El indicador de favorito cambia después de que la plataforma confirma el guardado.
- Ovinos/caprinos: crecimiento y conversión del lote, densidad y capacidad con datos capturados, evaluación seminal y acceso a gestaciones del espacio. La ruta de gestaciones indica que no filtra automáticamente la especie. No se agregan densidades ni porcentajes de alimentación supuestos.
- Bovinos: acceso a crecimiento del lote y herramientas existentes; las tres modalidades de dosificación abren su pantalla con una sola herramienta seleccionada. La capacidad se calcula con aritmética decimal exacta y se redondea hacia abajo: `0.58 m × 1 m × 100 animales/m² = 58`, sin perder una cabeza por redondeo binario. Se rechazan conteos fraccionarios de animales y porcentajes de ración mayores a 100. El texto de FCA describe ganancia de peso.
- Apiarios: cosecha por colmena productiva, cosecha por día e ingreso/saldo sobre costos capturados opcionales, con aritmética exacta. Ejemplo de prueba: 300 kg / 50 colmenas = 6 kg/colmena; 300 kg / 30 días = 10 kg/día. No representa metas biológicas ni utilidad contable completa. No guarda una cosecha automáticamente: los registros reales se capturan en el dashboard. Un costo o precio vacío queda pendiente, distinto de cero explícito.
- Consulta de granjas, calendario y dashboard con fecha/hora de consulta confirmada, limpiada al recargar o cambiar de contexto. Las unidades locales muestran su fecha de guardado real. Se distingue consulta de servidor de guardado local; no se afirma sincronización de datos que no se hayan sincronizado.
- Calendario sanitario por granja/caseta, con parvada opcional, tareas de vacunación, medicación o seguimiento, fecha, notas/responsable, aviso configurable de 0 a 90 días, estados pendiente/completada/cancelada y edición con control de versión. Las fechas programadas pueden estar en el futuro. Completar una tarea **no crea** un registro de vacuna/medicación aplicada: hay que capturar lo realizado en Sanidad.
- Los avisos del calendario aparecen **dentro de la app al consultar el calendario**, tomando el día del área de trabajo devuelto por el servidor. Se distinguen tareas próximas y vencidas, sin desfase por cambios de horario. No se envían notificaciones del teléfono, correos ni mensajes al equipo.

## Activación y datos

`supabase/proposed/23_aviculture_calendar.sql` es candidata: requiere M15 y la candidata 22 de granjas/sanidad. **No se aplicó a la cuenta real.** El cliente explica si el calendario aún no está habilitado; no simula tareas ni guardados.

La programación es compartida con miembros autorizados de la clínica/área. Admin/MVZ/auxiliar pueden capturar; miembros vigentes consultan su área. No hay acceso directo a tablas; los RPC verifican clínica, caseta, parvada, versiones, recibos idempotentes y auditoría. La tarea conserva su caseta/parvada al editar. Una caseta archivada no recibe tareas nuevas, pero permite cerrar/cancelar las anteriores. La tabla se incorpora al snapshot de clínica, preservando su autorización y los datos anteriores. El flujo de restauración operativa del servidor conserva su alcance previo; incluir la tabla en el respaldo no implementa su restauración completa.

Favoritos y unidades locales no se convierten automáticamente en registros compartidos. La nueva preferencia de favoritos no se sube automáticamente a Drive. La copia de presupuestos y los respaldos de la entrega anterior se conservan.

## Prioridades por especie

| Especie | Funciones disponibles / completadas aquí | Pendiente prioritario y dependencia |
|---|---|---|
| Bovinos | Lotes, métricas, eventos, alimento, gestaciones y cálculos de sesión | **P1:** genealogía con progenitores identificados por animal. **P2:** recomendaciones nutricionales por etapa y protocolos clínicos con fuentes validadas. |
| Ovinos/caprinos | Registros, gestaciones y herramientas manuales de crecimiento, densidad y capacidad | **P1:** genealogía. **P2:** alimentación y reproducción por etapa con fuentes específicas. |
| Aves | Crianza y guías, capacidad, índices, incubación, granjas/sanidad y calendario | **P0:** habilitar candidatas 22/23 tras revisión y actualizar app. **P2:** validar presión de agua, temperatura por edad y fichas de equipos pendientes. |
| Porcinos | Calculadoras por etapa, planes guardados, bioseguridad y referencias separadas | **P1:** validación de referencias de clase y constantes de conteo seminal; no promoverlas a recomendaciones oficiales por cambiar la interfaz. |
| Peces | Herramientas con referencias por especie, FCA, oxígeno, recambio y alimento medicado | **P1:** tablas de ración de bagre y datos de siembra de cachama/bagre. **P2:** factores de temperatura y oxígeno donde la fuente no publica valores. No se interpolan ni se reutilizan tablas de otra especie. |
| Abejas | Apiarios/lotes, cosechas y eventos; rendimiento de cosecha con datos propios | **P1:** trazabilidad por colmena individual. **P2:** protocolos sanitarios y calendarios de floración con referencias/región definidas. |
| Equinos | Pacientes, gestaciones y evaluación seminal | **P1:** genealogía. **P2:** nutrición por etapa y clínica avanzada con fuentes. |

**P0 común:** integrar y revisar los PR acumulados, aplicar las migraciones autorizadas y generar una actualización para el teléfono. El código preparado en GitHub no actualiza por sí solo una app instalada. No se fusionaron PR ni se publicó APK durante esta entrega.

**Siguiente mejora opcional:** notificaciones nativas del teléfono, con activación explícita por dispositivo, permisos y zona horaria. La configuración actual de avisos es del calendario dentro de la app.

## Verificación

Pruebas de separación de áreas, búsqueda, favoritos persistentes/aislados por usuario y clínica, pantallas de 320 px, cálculos exactos y saldos negativos, calendario por caseta y tareas programadas sin aplicaciones automáticas. Se adaptan las pruebas previas a las pestañas nuevas, conservando sus verificaciones de permisos y resultados. `supabase/tests/aviculture_calendar.sql` usa PostgreSQL aislado, reaplica las candidatas, comprueba recibos/versiones, auditoría, alcance de clínica y respaldo; **no ejecutar fixtures contra datos reales**. Los resultados finales y la punta verificada se registran en la descripción del PR.
