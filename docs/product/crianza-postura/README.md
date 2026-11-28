# Crianza de aves de postura

Implementación solicitada por Ale a partir de `especificacion-claude.md`. El documento adjunto se trata como especificación de producto y ejemplos numéricos, no como instrucciones del asistente.

## Acceso y comportamiento

Producción → Aves → Postura → **Crianza de pollitas · Bovans, Hy-Line y Lohmann**. Cada marca tiene su apartado, con sistema y edición explícitos. «Otra línea» admite captura propia. No hay cifras de granjas de demostración ni precios precargados.

El presupuesto calcula consumo, compra semanal, costos por etapa, superficie, piezas de equipo, frascos de vacunas, gas, cama, electricidad, compra de pollitas y margen opcional. Muestra rangos completos, costos pendientes, costo por pollona **alojada**, comparación de proyectos y gráfico de costos capturados. Las vacunas son presupuesto de presentaciones/aplicaciones capturadas, no una pauta sugerida. Peso y luz semanales permiten ajustes identificados del usuario. Las densidades y precios de las etapas requieren captura; el catálogo solo ofrece la referencia de transferencia Hy-Line con su condición y página.

Aritmética decimal exacta (`Quantity` / `BigInt`). Consumo = g/ave/día × aves × 7 / 1000. Compra = consumo × (1 + merma/100), redondeada al kg **más cercano por semana**; los medios suben. Superficies, piezas y frascos se redondean hacia arriba. Precios de hasta dos decimales. Sin un dato necesario se conserva «pendiente», nunca se sustituye por un valor inventado. Las cantidades de equipo aportadas en el proyecto son editables y se distinguen de los datos del fabricante. No se interpolan semanas ni se mezcla alimento de una edición con peso de otra.

Caso de aceptación del adjunto: 4,275 aves, 18 semanas, merma 7 %, consumos semanales propios `[9,14,20,25,30,35,40,44,47,50,53,56,59,62,65,68,73,76]`, alimento $12.50/$11.50/$10.50 por kg. Compras por etapa **4,258 / 9,286 / 12,903 kg**; costos **$53,225.00 / $106,789.00 / $135,481.50**. Total alimento **26,447 kg y $295,495.50**. El redondeo hacia arriba de cada compra no reproduce el ejemplo; por eso se usa el kg más cercano.

## Fuentes oficiales, consultadas el 27 de noviembre de 2026

Se incluyen hechos numéricos extraídos y sus referencias, no las guías completas. `guia_linea.csv` facilita la revisión; `assets/clinical/aviculture/guia_linea.v1.json` contiene los mismos 129 registros de siete conjuntos. Cada conjunto conserva URL, código/edición, fecha de consulta y SHA-256 del PDF; cada semana conserva la página PDF (contada desde 1). La fecha de subida o los metadatos del archivo no se toman como año editorial.

| Marca / sistema | Edición impresa | Páginas PDF | Guía oficial |
|---|---|---|---|
| Bovans Brown / jaula | L6230-1, sin año impreso | 6 | [Product Guide Cage](https://www.bovans.com/documents/2579/Bovans_Brown_CS_product_guide_cage_EN_L6230_-1_HyEGkWM.pdf) |
| Bovans Brown / alternativo | L6230-1, sin año impreso | 6 | [Product Guide Alternative](https://www.bovans.com/documents/2577/Bovans_Brown_CS_product_guide_alternative_EN_L6230-1.pdf) |
| Hy-Line Brown / jaula | Diciembre 2025 | 4–5 | [Performance Standards](https://www.hyline.com/filesimages/Hy-Line-Products/Hy-Line-Product-PDFs/Brown/BRN%20STD%20ENG.pdf) |
| Hy-Line Brown / alternativo | Mayo 2026 | 4–5 | [Alternative Systems](https://www.hyline.com/filesimages/Hy-Line-Products/Hy-Line-Product-PDFs/Brown/Brown%20Alt/BRN%20ALT%20STD%20ENG.pdf) |
| Lohmann Brown-Classic / jaula | 12/19, histórica | 15 | [Management Guide Cage, archivo](https://lohmann-breeders.com/media/2020/07/ManagementGuideLBClassicCage-EN.pdf) |
| Lohmann Brown-Classic / jaula | 08/21_V01-24 | 15 | [Management Guide Cage](https://lohmann-breeders.com/files/downloads/MG/Cage/LB_MG_Cage_LB-Classic_EN.pdf) |
| Lohmann Brown-Classic / alternativo | 04/18, histórica | alimento 24, peso 22, luz 15 | [Management Systems, archivo](https://lohmann-breeders.com/media/2021/03/LTZ_MG_management-systems_EN.pdf) |

Diferencias preservadas:

- Hy-Line alternativo publica consumo acumulado en **kg**, convertido a gramos en el catálogo; jaula ya lo publica en gramos. Semana 18 viene de la tabla de producción y no hereda su mortalidad reiniciada.
- Lohmann `08/21_V01-24` publica peso, **no alimento semanal**, en tabla 4. Sus celdas de alimento quedan vacías. La edición 12/19 tiene otra tabla; elegirla es una decisión explícita y conserva la etiqueta histórica.
- Luz de Lohmann alternativo procede del programa para **naves cerradas**; no se presenta como programa de naves abiertas. La semana 1 variable por días queda sin un único valor inventado.
- La guía Lohmann señala alimentación a libre acceso; sus consumos presupuestarios no se presentan como límites para alimentar.

Reproducir la extracción descargando los siete PDF con los nombres declarados en `scripts/build/build_pullet_guides.py`, instalar `pdftotext` y ejecutar `python scripts/build/build_pullet_guides.py --input-dir <carpeta-pdf>`. Revisar cambios de huellas/ediciones y contrastar las páginas antes de actualizar el catálogo. Las pruebas fijan columnas y conversiones con valores independientes.

## Guardado, varios establecimientos y sanidad

**Presupuestos:** base local Sembast, separados por usuario y área de trabajo. Se guardan entradas y copia completa de la guía para reabrir y comparar con la misma edición. PDF y XLSX reales se exportan desde el resumen. «Proyectos guardados» permite guardar copia JSON y recuperar copias sin sobrescribir proyectos existentes.

**Respaldo / Drive:** el archivo general incorpora los proyectos del usuario y área actuales como `device_assets`, con hash comprobado; conserva el snapshot original del servidor. La misma composición se usa en el guardado manual y en la subida cifrada a Drive ya existente. Se pueden recuperar proyectos desde JSON o `.vetbackup` cifrado, exigiendo la cuenta y área originales. Un archivo antiguo sin proyectos sigue siendo válido. Guardar un proyecto local **no** dispara una subida automática a Drive. Solo se incluyen proyectos de este dispositivo, no presupuestos privados de otros integrantes.

**Granjas → casetas → parvadas:** acceso directo en Producción → Aves → Postura → «Granjas, casetas y sanidad», sin exigir permiso de calculadoras clínicas. la nueva pantalla usa Supabase, compartido con los miembros autorizados de la clínica/área, según la preferencia confirmada por Ale. Permite varias granjas, nombres de caseta repetidos entre granjas y asignación de casetas previas sin granja. Conserva el módulo de producción y eventos previos. Vacunas, medicación y enfermedades se registran por caseta, con parvada opcional; guarda fecha, producto/dosis/vía capturados, diagnóstico, estado, notas y fechas de fin/retiro capturadas. Son entradas de bitácora, no prescripciones. El registro sanitario es acumulativo; el seguimiento se incorpora como un nuevo evento.

Admin/MVZ administran granjas y casetas; admin/MVZ/auxiliar capturan sanidad; miembros vigentes consultan su área. El servidor verifica los vínculos de granja/caseta/parvada, versiones e idempotencia, y deja auditoría. No se permite trasladar una caseta con historial a otra granja. Los errores y el backend ausente se muestran sin simular guardados ni registros.

**Activación pendiente:** `supabase/proposed/22_aviculture_farms_health.sql` es una migración candidata; no se ha aplicado en la cuenta real. Requiere M15, añade las seis tablas operativas avícolas al snapshot de clínica y conserva su autorización anterior. El flujo de recuperación de servidor preexistente sigue teniendo su alcance previo: exportar esas tablas no equivale a haber implementado su restauración operativa completa. La recuperación local de presupuestos sí está implementada. Sin la migración la app explica que el apartado compartido todavía no está habilitado.

Esta rama parte de la corrección de dashboards del PR #153, que a su vez depende del PR #145. No integra `main` antiguo ni publica APK, fusiona PR o aplica SQL remoto.

## Verificación

Pruebas: caso exacto de 4,275 aves; rangos y datos ausentes; aislamiento por cuenta/área; conservación de guía; entradas editadas; PDF/XLSX; recuperación sin sobrescritura y detección de manipulación; pantallas a 360 px; filtros sanitarios; reintentos con misma operación; respuestas atrasadas al cambiar de área. `supabase/tests/aviculture_farms_health.sql` ejecuta fixtures sintéticos en PostgreSQL aislado, reaplica la migración y comprueba permisos, dos granjas con Caseta 1, relaciones, auditoría/idempotencia y contenido del respaldo. **No ejecutar el fixture contra datos reales.**
