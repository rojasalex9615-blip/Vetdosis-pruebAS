# Especificación: Calculadora "Crianza de aves de postura" (VetDosis Pro, módulo Producción > Aves)

Para: DeepSeek (OpenHands) · De: Claude · Estado: borrador para revisión de Ale
Base: proyecto terminal de Producción de Aves de Postura (CUCBA), corregido, más guías de línea genética.

## 1. Objetivo
Dada una parvada de pollitas (0 a N semanas), calcular espacio, equipo, alimento, insumos, vacunas y costo por pollona. Todo editable por el usuario; la app no impone precios.

## 2. Reglas generales (importantes)
- **Ningún precio ni curva va fijo en el código.** Precios: los captura el usuario (con valores sugeridos editables). Curvas (g/ave/día, peso corporal, luz): salen de una tabla `guia_linea` con fuente citada.
- Mostrar siempre la fuente de cada dato de referencia (guía, año, edición). Si el usuario cambia un valor, marcarlo como "editado por el usuario".
- Según criterio de Ale: si dos guías dan rangos distintos, **mostrar ambos con su cita**, sin elegir uno.
- Dinero en MXN con 2 decimales; kg con 0 decimales en compra y 1 en consumo.
- Redondear **hacia arriba** todo conteo de piezas (equipo, frascos).
- Guardar entradas con nombre ("Proyecto crianza 2026-12") para reabrir y comparar.

## 3. Entradas
| Campo | Ejemplo | Nota |
|---|---|---|
| Número de pollitas | 4,275 | entero > 0 |
| Línea genética | Hy-Line Brown / Lohmann Brown-Classic / Otra | carga curvas de referencia |
| Sistema de alojamiento | Piso / Jaula | cambia densidad y consumo |
| Semanas de crianza | 17 o 18 | por defecto 17 (fin de crianza según guías) |
| % merma de alimento | 7% | parámetro del usuario (no viene de guía) |
| Precio alimento por etapa ($/kg) | 12.50 / 11.50 / 10.50 | Inicio / Crecimiento / Desarrollo |
| Densidad por etapa (aves/m²) | 13 y 8 | rango sugerido por etapa, editable |
| Costo por pollita ($) | 18.00 | |
| Gas ($/ave) | 2.50 | |
| Cama (kg/ave y $/kg) | 0.3 y 4.00 | |
| Luz ($ bimestral y duración) | 3,000 y 2.5 bimestres | o $/ave |
| Margen de ganancia (%) | 35% | opcional |
| Precios de equipo y vacunas | tablas editables | ver §5 y §6 |

Etapas por defecto: Inicio = sem 1–6, Crecimiento = 7–12, Desarrollo = 13–fin. Editables.

## 4. Fórmulas
1. **Espacio vital (m²)** = pollitas ÷ densidad. Calcular por etapa (ej.: 3,155 ÷ 13 = 242.7 m²; 3,155 ÷ 8 = 394.4 m²). Redondear a m² enteros hacia arriba.
2. **Consumo semanal (kg)** = g/ave/día × pollitas × 7 ÷ 1000.
3. **Compra semanal (kg)** = consumo × (1 + merma), redondeada al kg.
4. **Costo semanal** = compra × precio/kg de la etapa de esa semana.
5. **Totales por etapa**: sumar compra y costo de las semanas de cada etapa; total = suma de etapas. kg por ave = compra total ÷ pollitas.
6. **Equipo** = ROUNDUP(pollitas ÷ razón) × precio. Razones usadas en el proyecto: vitrolero 1/60, charola de iniciación 1/60, mini tolva 1/50, criadora de gas 1/800, bebedero de campana 1/80, tolva de desarrollo 1/40. Focos LED: 1 por cada 12–15 m². Divisiones temporales: 1 por metro lineal. Todo editable.
7. **Vacunas**: frascos = ROUNDUP(pollitas ÷ dosis por frasco) × precio. (ej.: 3,155 ÷ 1000 → 4 frascos.)
8. **Gas** = pollitas × $/ave. **Cama (kg)** = pollitas × kg/ave; **cama ($)** = kg × $/kg. **Luz** = gasto bimestral × bimestres.
9. **Costo real por pollona** = costo total ÷ pollitas. **Precio de venta** = costo real × (1 + margen). Mostrar también el desglose porcentual por rubro (gráfica de pastel).
10. Mortalidad opcional: aves vivas a la semana n = pollitas × (1 − mortalidad acumulada). Por defecto el consumo se calcula con las pollitas alojadas (criterio del proyecto); ofrecer interruptor "ajustar consumo por mortalidad".

## 5. Tabla de referencia de línea (`guia_linea`)
Campos por línea, sistema, semana: peso corporal (g, mín–máx), consumo (g/ave/día, mín–máx), consumo acumulado (g/ave), mortalidad acumulada (%), uniformidad (%), horas de luz, fuente (guía, año), página.

**Datos ya verificados (resumen de las guías; no son la tabla semanal):**

| Dato | Hy-Line Brown (Intl. standards, ene 2024) | Lohmann Brown-Classic |
|---|---|---|
| Viabilidad en crianza (a 17 sem) | 98% | 98–99% (jaula) |
| Alimento consumido 1–17 sem | 6,069 g/ave (guía 2018: 5.75–6.13 kg) | 5.7–5.9 kg en alojamiento alternativo |
| Peso corporal a 17 sem | 1,580 g (variedad alt. 1,460 g; guía 2018: 1.40–1.48 kg) | 1.42 kg |
| Semana 1 | 12–14 g/ave/día; acumulado 84–98 g | — |
| Semana 2 | 17–21 g/ave/día; acumulado 201–244 g | — |
| Semana 3 | 20–25 g/ave/día; acumulado 343–418 g | — |

Notas de manejo citadas por las guías:
- Hy-Line, sistemas alternativos: densidad útil recomendada en crianza al transferir: 15 aves/m² en sem 15, 14 en 16, 13 en 17, 12 en 18.
- Lohmann: el alimento se ofrece siempre a libre acceso; las cifras de consumo son guía aproximada, **nunca un límite**.
- Hy-Line: cambiar de dieta según **peso corporal**, no según edad.
- Pesaje: muestra de 100 pollitas, de la semana 4 en adelante, cada 2 semanas. Uniformidad = % de aves dentro de ±10% del peso promedio; meta ≥ 90% (guía Alberta Agriculture; la tabla de Hy-Line fija metas por semana).

**PENDIENTE (no pude leer las tablas completas en línea):** extraer semana por semana (1–17/18) peso, consumo y acumulado de:
- Hy-Line Brown Commercial Management Guide / Performance Guide (jaula y alternativo): hyline.com
- Lohmann Brown-Classic Management Guide, Table 5 (peso y consumo): lohmann-breeders.com
- Bovans Brown Management Guide (la citaba el proyecto)
Ale puede subir los PDFs; extraer a CSV con la fuente y la página en cada fila.

## 6. Pantallas
1. **Entradas** (lista corta + "Avanzado" plegable para precios y razones).
2. **Resumen**: tarjetas con costo total, costo por pollona, precio de venta, kg de alimento, m² requeridos.
3. **Alimento**: tabla semanal con etiqueta a la izquierda y valor a la derecha, notas aclaratorias en gris pequeño; comparar contra la guía de la línea (±) cuando exista.
4. **Equipo y vacunas**: tablas editables con total por rubro.
5. **Desglose** (pastel) y exportar a PDF/Excel.
Estilo según lo que Ale pidió para la app: jerarquía visual clara, notas en texto pequeño gris.

## 7. Validaciones y avisos
- Avisar (sin bloquear) si el consumo por ave a 17 sem queda fuera del rango de la guía elegida.
- Avisar si semanas > 18 o pollitas ≤ 0.
- Mostrar "sin datos de guía para esta línea/semana" en vez de inventar valores.

## 8. Errores del documento fuente que NO deben copiarse
- Costos semanales ×10 en las semanas 1, 3, 5, 11, 12, 14 y 17; el total por etapa de Inicio dice $390,625 y es $39,062.50.
- La columna "Consumo (kg)" estaba en gramos con separadores mal puestos; "Compra total" se rotulaba en pesos y eran kg.
- La semana 12 usaba $10.50/kg en la tabla semanal y $11.50 en el total por etapa.
- Cama: "9,465" es 946.5 kg (3,155 aves × 0.3 kg).
- Los g/ave/día del proyecto (9 y 14 g en sem 1–2) quedan por debajo de las guías (12–14 y 17–21 g); su consumo acumulado a 17 sem (≈5.4 kg) también queda abajo del rango publicado (≈5.6–6.1 kg). Por eso las curvas deben venir de la guía y no del proyecto.

## 9. Caso de prueba (debe coincidir exactamente)
Entradas: 4,275 pollitas, 18 semanas, merma 7%, etapas 1–6 / 7–12 / 13–18, precios 12.50 / 11.50 / 10.50, g/ave/día por semana = 9, 14, 20, 25, 30, 35, 40, 44, 47, 50, 53, 56, 59, 62, 65, 68, 73, 76, gas $2.50/ave, cama 0.3 kg/ave a $4.00/kg.
Salidas esperadas: compra Inicio 4,258 kg ($53,225.00); Crecimiento 9,286 kg ($106,789.00); Desarrollo 12,903 kg ($135,481.50); total alimento 26,447 kg ($295,495.50); gas $10,687.50; cama 1,282.5 kg ($5,130.00).
Referencia: `Aves_Gas_Alimento_Cama_4275.xlsx`.
