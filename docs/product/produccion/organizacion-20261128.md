# Organización del módulo Producción

Esta propuesta continúa sobre el PR #154 de crianza y sanidad, que conserva las correcciones de dashboards de #153/#145.

- Los accesos genéricos heredados de ración, conversión, densidad, capacidad y dosis seminales se ofrecen en Bovinos, tanto en catálogo como dashboard. La ración por porcentaje no se presenta como referencia universal para aves, peces o abejas. Las fórmulas no cambian.
- La sección genérica de medicación por cabeza/lote, agua y alimento se limita al apartado Bovinos. «Agua» en esta sección es medicación en agua de bebida, no una estimación de necesidades hídricas. Conversión alimenticia y cálculos de agua sí existen para otras especies: se mantienen sus herramientas específicas, por ejemplo FCA y recambio acuícola, índices avícolas y conversión por etapa porcina.
- Porcinos y Peces tienen directorios por actividad con una pantalla por calculadora. El formulario, sus resultados, fuentes y controles relacionados permanecen juntos. Se conservan los permisos de calculadoras y de costos, los repositorios y los avisos de referencias de clase.
- Las calculadoras bovinas heredadas abren pantalla completa desde catálogo y dashboard. El dashboard de otras especies enlaza al catálogo de esa especie, donde se elige actividad.
- Los grupos de chips de actividad, especie acuícola, modelos/etapas porcinas y evaluación seminal se presentan en una sola fila con scroll horizontal. Los botones de acciones independientes mantienen su distribución.

## Sugerencias posteriores, todavía no implementadas

1. Separar visualmente Registros, Calculadoras y Referencias en cada actividad; mostrar siempre especie, etapa y sistema.
2. Favoritos e historial de cálculos con sus entradas y fuente, sin confundirlos con registros reales.
3. Calendario de vacunación y seguimiento de tratamientos por caseta, con avisos configurables y sin inventar pautas.
4. Estado visible de guardado/sincronización y fecha de última actualización; identificar datos pendientes.
5. Búsqueda de calculadoras por objetivo («calcular alimento», «dimensionar corral») y revisión visual en teléfonos estrechos.

Pruebas de navegación: directorio sin formularios montados, apertura de una sola herramienta, regreso al directorio, ocultamiento de herramientas genéricas en seis especies y chips de una fila accesibles a 320 px. Se adaptan las pruebas de menú previas a la nueva navegación, conservando las verificaciones de resultados y permisos.
