# Integridad de datos en exóticos y producción

Encargo de Ale: corregir ambos dashboards porque muestran datos erróneos o ficticios y revisar errores de la app. Sesión: Codex, 27 de noviembre de 2026 (Ciudad de México).

## Base y dependencia

Repositorio: `rojasalex9615-blip/Vetdosis-pruebAS`.
Rama de esta entrega: `fix/dashboards-exoticos-produccion-20261127`.
Base: `arena/62963890-vetdosis-pruebas`, commit `62cfe0462fd23f39c061ce507c7ce79f510cd5a7`, propuesta #145.

La beta consultada (`70b98a0`) todavía contiene la granja ficticia de 480 vacas. La propuesta #145 ya sustituye ese catálogo por repositorios y estados vacíos; también incorpora el dashboard de exóticos. Esta entrega completa y prueba esa propuesta. Debe integrarse con #145 antes de preparar un APK: aplicarla sola sobre `main` o la beta anterior omitiría sus dependencias.

Se leyó el tablón #31 y sus novedades. El trabajo visual de #149 figura integrado en la beta; esta entrega no modifica esos componentes compartidos. La revisión externa sigue pendiente; no se atribuye acuse ni resultado a CodeRabbit.

## Correcciones

- Producción y su catálogo abren el vademécum y la prescripción reales. Se retiraron la lista fija de medicamentos con dosis y retiros llamados «oficiales» y el formulario que mostraba una receta prellenada y confirmaba una emisión inexistente.
- «Registros Productivos» usa la captura persistente existente. Desde el catálogo abre el dashboard de la especie elegida. Desde el dashboard valida sesión, permiso, repositorio y datos antes de abrir la captura; ya no muestra un mensaje de guardado sin escribir.
- Se retiraron también los rangos fisiológicos del catálogo de demostración, que carecían de fuente. El acceso abre Cálculos clínicos, donde está la biblioteca de referencias con sus fuentes y estados.
- Las calculadoras de producción y dosificación masiva empiezan vacías. Un dato ausente, no numérico, infinito o negativo no se sustituye por 1. Admiten coma decimal y validan concentración de hasta 100 %. Se liberan sus controladores al cerrar.
- Los dashboards de exóticos/producción y los paneles de alimento/reproducción invalidan solicitudes anteriores al cambiar de clínica, usuario o repositorio. Producción también captura la especie de cada consulta. Se vacían los datos anteriores mientras carga; una respuesta tardía no puede reemplazar el resultado vigente ni su estado de error. El buscador de exóticos también pierde los resultados anteriores.
- El selector de grupo de exóticos actualiza la especie y constante de la calculadora alométrica. Se descartan entradas no finitas en esa pantalla, conservando sus fórmulas.
- La clasificación de especies reconoce términos completos, conserva los plurales y el caso de avestruz; «hepatopatía» no convierte un paciente en ave por contener «pato».
- Las fechas obligatorias de los repositorios no se reemplazan por la fecha actual. Un registro incompleto produce un fallo de lectura en vez de aparentar una medición reciente.
- Las consultas paralelas de ambos repositorios se esperan juntas, incluyendo sus errores.
- Los cuatro traductores de errores conservan las excepciones que ya estaban traducidas. Así se muestran correctamente la métrica obligatoria, el error de conexión y el reintento.
- Se retiró el workflow temporal `zz-diagnostico-analyze.yml`, que podía terminar en verde aunque fallaran análisis o pruebas. Permanecen los workflows de validación normales.

## Validación

Flutter 3.50.0 / Dart 3.14.0. SDK y cachés instalados en el directorio de trabajo.

- `flutter analyze --no-pub --no-fatal-infos`: 0 errores, 0 warnings y 321 avisos informativos de deprecación de `material.dart`.
- 12 regresiones nuevas en `test/dashboard_data_integrity_test.dart`: respuestas atrasadas, cambio de clínica, buscador, rutas reales, captura, especie del catálogo, entradas de calculadoras, selector de grupo, fechas y clasificación.
- `flutter test --no-pub --concurrency 4 --reporter expanded`: **1387 aprobadas, 1 omitida, 0 fallos**, sobre `8bc7bd1`.
- Después se amplió el reconocimiento de plurales y avestruz para conservar las especies que reconocía el clasificador anterior: **45 pruebas de integridad y exóticos aprobadas** sobre ese ajuste final, y análisis repetido sin errores ni warnings.
- Las 28 pruebas enfocadas de dashboard, calculadoras y unidades también aprobaron.
- En GitHub pasaron los contratos Flutter, contratos de pacientes/contactos/cobros, SQL de módulos/dashboard, finanzas y actualización aislada sobre `8bc7bd1`. La validación de Flutter/APK sintética seguía en ejecución en esa consulta. Octopus omitió la revisión por ser borrador; no hay revisión externa favorable acreditada.

## Límites

Verificación local con repositorios de prueba y fixtures. No se consultaron datos de pacientes ni se comprobó el contenido actual de Supabase; las tablas y contratos se contrastaron con las migraciones versionadas. No se aplicó SQL, no se fusionó la beta, no se publicó APK y no se probó en teléfono. Los estados vacíos dependen de que el servidor responda correctamente: un fallo de lectura se presenta como error, no como cero registros.
