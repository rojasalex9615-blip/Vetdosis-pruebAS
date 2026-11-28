# VetDosis plan de aceptación y piloto de beta

Corte del 28 de noviembre de 2026. Objetivo: iniciar un grupo pequeño con una versión identificable, guardados comprobados y un alcance que cada participante entienda. La primera ronda será con datos ficticios en espacios de prueba; incorporar datos reales exige una decisión posterior basada en los resultados.

La candidata de aplicación es **c3d6f4137649bed3557dbfa266c3a4bf784110ef**, reunida en el [PR 158](https://github.com/rojasalex9615-blip/Vetdosis-pruebAS/pull/158). Sus comprobaciones técnicas de integración están aprobadas y el PR 158 ya se fusionó a beta en 990b6c2; el plan del PR 159 se fusionó en f3e9b35. La [ronda posterior de pantallas](../../audits/integracion-pantallas-20261128.md) registra las correcciones adicionales y la revisión de ramas antiguas. La suite local completa pasó 1456 pruebas y omitió 1. Esto acredita pruebas automatizadas, no aceptación de todos los módulos en teléfono.

La [compilación firmada 46126044318](https://github.com/rojasalex9615-blip/Vetdosis-pruebAS/actions/runs/46126044318) terminó con éxito y publicó los [APK de pruebas](https://github.com/rojasalex9615-blip/Vetdosis-pruebAS/releases/tag/beta-apk), versión **218017794**, canal beta y proyecto Pruebas. BUILD-INFO corresponde al commit indicado; sus hashes coinciden con los digests de ambos APK publicados (arm64 y ARM de 32 bits). El pipeline aprobó firma, registro de publicación y descarga. La instalación y aceptación en teléfono siguen pendientes. La etiqueta beta-apk es móvil: volver a comparar BUILD-INFO y versión antes de distribuir una descarga posterior.

La [matriz editable de pruebas](matriz-aceptacion-20261128.csv) contiene **45 casos**: 20 antes del grupo, 22 por área, 1 antes de datos reales y 2 fuera del alcance inicial, con sus pasos y resultados esperados. Todas las ejecuciones manuales comienzan en **Pendiente**. La coordinación de desarrollo conserva el [tablón existente 31](https://github.com/rojasalex9615-blip/Vetdosis-pruebAS/issues/31); este plan no crea otro tablero ni invita usuarios.

## Áreas en las que debemos enfocarnos ahora

| Orden | Trabajo concreto | Condición para terminar | Responsable propuesto |
|---|---|---|---|
| 1 | Cerrar la candidata de integración y disponer del APK correcto | Revisión del PR resuelta; mismo código, BUILD-INFO, firma e instalación identificados; versión beta válida para guardar | Desarrollo y revisión; Ale confirma el APK que probará el grupo |
| 2 | Probar identidad, roles, clínicas y guardados | Dos cuentas y dos clínicas aisladas; revocación efectiva; error de conexión visible; reintentos sin duplicados; lectura desde otro teléfono | Desarrollo con dos participantes de prueba |
| 3 | Validar el recorrido diario mínimo | Paciente → cita → cálculo de prueba; inventario → venta → devolución/corte; resumen coherente y reapertura sin pérdida | Participante de operación; MVZ para revisar cálculos y actos profesionales |
| 4 | Validar Producción avícola compartida | Dos granjas, casetas y parvadas distintas; calendario y sanidad separados; mismo registro consultable por el equipo autorizado | Participante de producción y desarrollo |
| 5 | Probar archivos, respaldo y experiencia Android | Exportar y volver a abrir un respaldo cifrado; cámara/archivos/PDF sin pérdida de captura; textos y botones utilizables | Dos participantes con teléfonos distintos |

Las nuevas funciones, genealogía, automatizaciones y ampliaciones de referencias quedan después del piloto. Corregir un fallo crítico de una función ya incluida sí entra en esta fase.

## Alcance de la primera ronda

- **Núcleo obligatorio:** acceso, cuenta/clínica, permisos, Inicio, pacientes, agenda, cálculos aritméticos de prueba, inventario/caja con operaciones ficticias y respaldo protegido.
- **Primer recorrido adicional:** granjas/casetas/parvadas, sanidad y calendario avícola, por ser la ampliación compartida recién habilitada.
- **Rondas condicionadas:** recetas, documentos y hospitalización solo con las identidades, habilitaciones y permisos que correspondan; las pruebas de rechazo a cuentas no autorizadas se hacen desde el inicio.
- **Exploración posterior por especie:** bovinos, ovinos/caprinos, porcinos, peces, abejas, equinos y exóticos. Incluir solo las áreas que los participantes realmente puedan evaluar.
- **Fuera del uso operativo inicial:** cobros automáticos de suscripciones/pasarelas, sincronización clínica offline, restauración integral desde la app, notificaciones nativas del calendario avícola, recomendaciones sin fuente verificada y automatizaciones de IA. Que una pantalla exista no amplía este alcance.

Si se quiere usar una función condicionada durante el piloto, primero debe pasar sus casos de aceptación. No se presenta el piloto como aprobación de toda la app.

## Mapa de módulos y datos

Estado técnico se refiere al código de la candidata y a las verificaciones citadas; ninguna fila equivale a aprobación en teléfono. P0 indica preparación obligatoria; P1, validación del área antes de incorporarla al grupo; P2, ampliación posterior.

| Área o módulo | Qué hay y dónde guarda | Qué falta comprobar o limitar | Prioridad y casos |
|---|---|---|---|
| Instalación y versión | APK beta firmado en pipeline; control de build en el servidor | Descarga correspondiente al commit, instalación/actualización y sesión real con esa versión | P0 · REL-01/02 |
| Cuenta, clínica y permisos | Membresías y permisos de servidor; caché local de sesión/membresías | Google/correo, salida, revocación, vencimiento, dos cuentas/dos clínicas y rechazo de actos no habilitados | P0 · ACC-01 a 06 |
| Inicio, navegación y estadísticas | Cifras consultadas de repositorios autorizados; ajustes visuales preparados | Reconciliar con los registros; vacío distinto de consulta fallida; iconos, tamaños y rutas accesibles | P0 · NAV-01, DAT-04 |
| Guardado transversal | RPC y controles propios de cada módulo; hay preferencias y borradores locales | Consultar en segundo dispositivo lo que se declara compartido; reintentos, conflicto y pérdida de red sin falso guardado | P0 · DAT-01 a 03 |
| Pacientes y agenda | Expediente/citas en servidor según permisos | Alta/edición/reapertura, asociación correcta de paciente, cambios de cita y horario de clínica | P0 · PAT-01, AG-01 |
| Cálculos y vademécum | Aritmética y referencias de assets/servidor; fuentes con estados diferentes | Oráculos manuales, unidades, ceros/vacíos y fuente/edición; una referencia pendiente no es pauta aprobada | P0 · CAL-01/02 |
| Recetas y control de medicamentos | Documentos y actos separados en servidor | Identidad del autor, permisos vigentes, versiones y rechazo al no habilitado; supervisión profesional para aceptación positiva | P1 · RX-01; rechazo básico en ACC-03 |
| Hospitalización | Registros de servidor; alarmas locales y componentes de push requieren prueba Android propia | Ingreso → programación → aplicación explícita → alta; alertas con app cerrada; no confundir vencimiento de horario con aplicación | P1 · HOS-01/02 |
| Inventario, lotes y caja | Existencias, movimientos, ventas/cortes de servidor; catálogo y permisos propios | Caducados, unidad de stock, centavos, devoluciones, reversos y acceso financiero | P0 · INV-01, POS-01; P1 · POS-02 |
| Formatos y consentimientos | Versiones, documentos y firmas según permisos de servidor | PDF correcto, autorías, compartir/imprimir; consentimiento no significa acto realizado | P1 · DOC-01 |
| Archivos, escáner y laboratorio | Captura en teléfono; adjuntos según repositorio; OCR produce lecturas revisables | Permiso denegado, cancelar/reintentar, archivo de clínica correcta; corroborar analito y unidad antes de aceptar OCR | P1 · FIL-01 |
| Respaldo y Drive | Snapshot de clínica, archivo cifrado y revisión de integridad; Drive depende del método/configuración | Inspeccionar no restaura; probar exportación y relectura. OAuth Drive y sincronización remota se aceptan por separado | P0 · BAK-01; P1 · BAK-03; antes de datos reales · BAK-02 |
| Aves y crianza | Granjas/casetas/parvadas/sanidad/calendario en servidor. Presupuestos de crianza guardados localmente por cuenta/clínica y exportables; favoritos/unidades locales no son colaboración | Dos granjas/casetas, lectura del equipo, guías por marca/edición y aislamiento. Avisos del calendario dentro de la app; sin notificación nativa. Completar tarea no registra una vacuna aplicada | P1 prioritario · AVI-01 a 05 |
| Bovinos | Lotes, alimento, eventos/gestaciones y cálculos disponibles; persistencia según formulario | Recorrido real de lote y aritmética; diferenciar cálculo de sesión de registro guardado. Genealogía individual pendiente | P1 · PRO-01 |
| Ovinos y caprinos | Registros/gestaciones y herramientas manuales; ruta de gestaciones puede no filtrar especie | Especie visible, crecimiento, capacidad y límites; no rellenar valores nutricionales supuestos. Genealogía pendiente | P1 · PRO-02 |
| Porcinos | Calculadoras por etapa, bandas/planes y referencias | Reabrir plan; especie/actividad correctas; referencias de clase conservan su estado | P1 · PRO-03 |
| Peces | Herramientas y referencias por especie | Unidades y especie; no tomar datos de otra especie donde falta fuente. Tablas y factores pendientes siguen identificados | P1 · PRO-04 |
| Abejas | Lotes/apiarios, cosechas/eventos y cálculo manual de rendimiento | Guardado explícito de cosecha; costo vacío distinto de cero; trazabilidad por colmena individual pendiente | P1 · PRO-05 |
| Equinos | Pacientes, gestaciones y evaluación seminal disponibles | Asociación al animal/especie y alcance del cálculo; genealogía y ampliaciones clínicas pendientes | P1 · PRO-06 |
| Exóticos y silvestres | Dashboard y registros disponibles según permisos | Cifras derivadas de registros propios; cambio de especie/contexto sin datos anteriores ni prototipos ficticios | P1 · EXO-01 |
| Equipo, servicios y administración | Agenda/servicios, avisos, pendientes, proveedores, promociones y productividad según servidor y permisos | Destinatarios, información financiera y vínculo de cada acción. Mensajería manual no equivale a push/Realtime | P1 · TEAM-01, POS-02 |
| Control de asistencia | Checados/configuración en servidor; QR/ubicación dependen del dispositivo | Permisos, zonas horarias, correcciones e información accesible por rol | P1 · ATD-01 |
| Perfil, ajustes, soporte e información | Ajustes locales; identidad, soporte y archivos según servicio | Conservar preferencias entre sesiones sin compartirlas como datos de clínica; ticket/adjunto y textos de ayuda utilizables | P1 · NAV-01, SUP-01 |
| Asistente IA y ayuda incluida | Pantallas y conectores; IA de ayuda y chat son productos separados | Backend, claves, cuotas, permisos y privacidad necesitan validación propia; no sustituye una decisión clínica | P2 · AI-01 |
| Planes, producto y costos | Catálogo/condiciones y componentes de planes | Confirmar estado publicado y cobros realmente habilitados; no probar pagos reales en esta ronda | P2 · PLN-01 |

El calendario se habilitó en **Supabase Pruebas**, junto con M15 y granjas/sanidad 22, el 28 de noviembre. La prueba transaccional comprobó guardado, lectura, finalización, respaldo e aislamiento y terminó en rollback. No acredita todavía el recorrido desde una sesión del APK. [Evidencia de activación](../produccion/activacion-calendario-20261128.md).

## Lista de aceptación para abrir el grupo

Marcar una casilla solo después de registrar versión, dispositivo, resultado y evidencia en la matriz.

- [ ] **Candidata definida:** revisión de integración resuelta y commit elegido por la titular. Si se ensaya una rama sin fusionar, su condición de candidata queda explícita y no se cambia silenciosamente el APK del grupo.
- [ ] **APK disponible:** firma, versión incremental, BUILD-INFO y registro beta corresponden a esa candidata; descargar e instalar en dos teléfonos. REL-01/02.
- [ ] **Acceso efectivo:** iniciar sesión, recuperar sesión y salir; probar las identidades separadas y el rechazo con permisos ausentes. ACC-01 a 06.
- [ ] **Aislamiento:** cambiar de usuario/clínica y revocar un permiso sin que queden datos o acciones del contexto anterior. ACC-03/04/05, DAT-03.
- [ ] **Guardado real:** capturar, consultar, cerrar/reabrir y consultar desde otro teléfono; pérdida de red y doble toque no provocan falso éxito ni duplicado. DAT-01/02/03.
- [ ] **Recorrido mínimo:** paciente/cita, cálculo aritmético conocido e inventario/venta ficticios con resultado correcto. PAT-01, AG-01, CAL-01/02, INV-01, POS-01.
- [ ] **Interfaz utilizable:** se alcanzan acciones y notas en pantalla estrecha y texto ampliado; el dashboard refleja registros propios. NAV-01, DAT-04.
- [ ] **Respaldo revisable:** exportar, abrir de nuevo y verificar archivo cifrado, contraseña y pertenencia de clínica. BAK-01. No marcar esto como restauración de servidor.
- [ ] **Registro de incidencias preparado:** plantilla disponible, participantes y personas de revisión confirmados; no quedan fallos críticos/altos del alcance incluido.
- [ ] **Alcance entendido:** todas las pruebas P0 de la etapa Antes del grupo aprobadas, y los casos del área que se habilite aprobados antes de usarla. Lo excluido queda identificado para el grupo.

**Para aceptar datos reales después del piloto:** además, completar BAK-02 mediante recuperación en un entorno aislado, comprobar integridad de registros/documentos y documentar un procedimiento de recuperación viable con su responsable. Para uso clínico, aprobar también los recorridos profesionales y las alertas que realmente se pretenda usar. Si estos requisitos siguen pendientes, conservar el piloto con datos ficticios; no presentar la inspección de un archivo como recuperación completa.

## Cómo ejecutar las pruebas

Equipo propuesto de **3 a 5 participantes**, por confirmar: titular/coordinación, MVZ habilitado para las pruebas que lo requieran, operación/auxiliar y una persona de producción. Una persona puede cubrir más de un recorrido; usar cuentas separadas para probar roles. No se asignan facultades profesionales por participar.

Usar **dos clínicas de prueba y al menos dos teléfonos Android** de los modelos/versiones que tenga el grupo. Registrar fabricante, versión Android, tamaño de texto y versión APK. La matriz de dispositivos se completa antes de ejecutar; no se afirma compatibilidad con modelos no probados.

Preparación ficticia propuesta: dos pacientes de prueba, dos productos (uno con lotes vigentes y caducados), una venta reversible y dos granjas con una caseta cada una, usando nombres repetidos de caseta para comprobar su alcance. Se capturan dentro de los espacios de prueba. No ejecutar fixtures SQL de pruebas sobre datos existentes.

| Etapa | Actividad | Salida necesaria |
|---|---|---|
| Preparación interna | Ejecutar los P0 Antes del grupo; acordar alcance y cuentas | Todas esas filas Aprobado, evidencia completa y sin incidentes críticos/altos abiertos |
| Primera sesión del grupo | Instalar la misma candidata y repetir acceso, paciente/cita, guardado y lectura compartida | Confirmación por participante; anotar diferencias de dispositivo |
| Rondas por área | Probar caja, aves y luego las áreas seleccionadas; casos positivos y de rechazo | Aprobación de cada recorrido por quien puede evaluar su resultado |
| Revisión y regresión | Revisar incidencias, corregir y repetir el caso fallido más sus recorridos relacionados | Versión nueva identificada, evidencia conservada, sin cambiar a Aprobado por cerrar un ticket |
| Decisión de salida | Tras aproximadamente 7 a 10 días de uso controlado, evaluar el alcance cubierto | Continuar piloto, reducir alcance o aceptar la beta cerrada; la duración no aprueba casos pendientes |

Los 7 a 10 días son una duración propuesta desde que pase la preparación, no una fecha de lanzamiento comprometida. La admisión global puede permanecer cerrada; las incorporaciones concretas siguen la configuración autorizada de la beta.

## Resultados e incidencias

Estados permitidos: **Pendiente, En ejecución, Aprobado, Falló, Bloqueado, Fuera del alcance**. Registrar motivo para Bloqueado o Fuera del alcance; ninguno cuenta como aprobado. No cambiar las filas manuales por el resultado de un test automático.

Cada fila ejecutada necesita: persona, APK/commit, teléfono/Android, fecha, evidencia y referencia de incidencia si falla. Si un caso requiere varios dispositivos, roles o variantes, conservar un registro por variante y no sobrescribir un resultado anterior. Mantener las evidencias con datos de personas en un espacio privado; en el repositorio público solo plantilla, identificadores de caso y resúmenes sin datos clínicos/personales.

| Severidad | Ejemplo | Respuesta |
|---|---|---|
| Crítica | Otro usuario/clínica ve datos ajenos; resultado clínico o dinero incorrecto; pérdida/corrupción de registros | Detener el recorrido afectado; ante aislamiento o daño transversal, pausar el piloto. Corregir y repetir antes de reabrir |
| Alta | No se puede guardar/consultar una función incluida, identidad de autor equivocada o falsa confirmación | Bloquea incorporar esa área; si afecta al núcleo obligatorio, bloquea abrir el grupo |
| Media | Existe un camino alternativo válido, sin pérdida de datos ni resultado incorrecto | Registrar y acordar si se reduce el alcance mientras se corrige |
| Baja | Detalle visual que no tapa información o acciones | Programar después de los bloqueantes |

## Decisión al cerrar el piloto

- Todos los P0 aplicables y los recorridos de las áreas incluidas aprobados con evidencia.
- Ninguna incidencia crítica o alta abierta dentro de ese alcance.
- Dos sesiones completas de guardar y consultar, en días distintos y desde los dispositivos elegidos, sin pérdida ni duplicación de registros.
- Las funciones excluidas y referencias pendientes siguen claramente identificadas.
- La versión aceptada, sus notas de cambios y el procedimiento de soporte/recuperación están disponibles.
- La titular decide si el alcance probado permite continuar o cerrar la beta; las pruebas automáticas y la duración por sí solas no toman esa decisión.

## Fuentes de este corte

- [Catálogo de secciones](../../../lib/modules/core/domain/section_catalog.dart) para el mapa funcional.
- [PR 158](https://github.com/rojasalex9615-blip/Vetdosis-pruebAS/pull/158) y [ejecución del APK](https://github.com/rojasalex9615-blip/Vetdosis-pruebAS/actions/runs/46126044318) para código, pruebas y distribución.
- [Producción por especie](../produccion/pendientes-y-prioridades-20261128.md) y [activación posterior](../produccion/activacion-calendario-20261128.md): la habilitación del calendario ya supera el pendiente histórico de aplicar 22/23.
- [Respaldo protegido y recuperación](../../respaldo-protegido-recuperacion.md) y [Drive OAuth](../../respaldo-drive-oauth-beta.md): métodos y límites distintos.
- [Arranque de sincronización](../../../lib/main.dart): el motor se crea sin adaptadores de dominio; no se declara captura clínica offline conectada.
- [Prueba operativa histórica](../../prueba-operativa-beta.md): conserva antecedentes de permisos y pruebas; no acredita el teléfono ni la versión actuales.
