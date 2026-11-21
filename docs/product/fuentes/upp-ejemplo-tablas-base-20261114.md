# upp-ejemplo-tablas-base-20261114.xlsx

Extraido de `upp-ejemplo-tablas-base-20261114.xlsx` para poder leerlo sin herramienta de hoja de calculo.
Las celdas muestran la formula cuando la hay; el valor calculado solo
aparece si el libro lo guardo en el ultimo guardado.

## Hoja `Leeme`

Rango con datos: 8 filas x 2 columnas.

| UPP de ejemplo (basada en Rancho La Huamuchilera) – tablas base para app (producción + contaminación) |  |
| --- | --- |
| Colores | Azul = dato editable. Negro = fórmula. VERDE CLARO = dato del Proyecto Semestral 2022 sobre Rancho La Huamuchilera: NO confirmado como real con el productor (parte viene de la visita y fotos; parte se completó para cumplir requisitos de la clase). AMARILLO = dato que falta o es supuesto. |
| Fuente de datos UPP | Proyecto Semestral Clínica de Cerdos, Equipo #5 B01 (01/12/2022). Úsalo como caso ILUSTRATIVO, no como datos medidos de la granja, hasta confirmarlos con el productor. Ver hoja Datos_UPP. |
| IMPORTANTE | Todo lo que NO está en verde viene de referencias típicas puestas de memoria y NO está verificado (NRC 2012, FEDNA, ASAE D384.2). En especial proteína cruda y fósforo de la dieta: tu UPP usa mezcla de granos (maíz, cebada, avena, trigo) + vitaminas y minerales; su proteína suele ser menor que la de dietas comerciales, así que el N excretado de esta tabla probablemente está sobreestimado hasta que pongas la composición real. |
| Supuestos míos | Reparto de las 100 hembras en gestantes (87) y lactantes (13) y de las 120 cerdas de engorda en desarrollo (60) y finalización (60): NO vienen del documento. Precios de alimento: ejemplo. |
| Hojas | Datos_UPP = lo que dice el proyecto 2022 y lo que falta confirmar. Supuestos = parámetros globales. Fases = tabla base. Lote_Calc = alimento, agua, costos, espacio. Contaminacion = excreta, N, P, efluente, superficie agrícola. Faltantes_Normativa y Mitigacion = pendientes y medidas. |
| Limitación | El balance de N y P en cerdas es aproximado (lactancia incluye lo retenido por la camada). Tu UPP maneja excreta sólida y la usa como estiércol en pastos, no hay fosa de purín: la columna 'Efluente' es excreta + agua perdida + lavado y sirve como orden de magnitud. |

## Hoja `Datos_UPP`

Rango con datos: 27 filas x 4 columnas.

| Datos del Proyecto Semestral 2022 (Rancho La Huamuchilera) – sin confirmar – y lo que falta |  |  |  |
| --- | --- | --- | --- |
| Atención: no presentar estos datos como medidos en la granja hasta confirmarlos con el productor. Mientras tanto, rotular el caso como ilustrativo. |  |  |  |
| Dato | Valor | Dónde se usa | Nota |
| Fin zootécnico / tipo / sistema | Carne / cebadero / mixto | Descripción | Ubicación: Tehuitzingo, Puebla (clima cálido 20–40 °C). |
| Razas | Landrace y Duroc | Descripción | Cruzas; vientres seleccionados a 4–5 meses y 100–110 kg. |
| Inventario total | Hembras 100; machos 20; lechones 20; engorda 120 | Lote_Calc | Tabla 1 del documento. |
| Corrales | Engorda 10 (3×4 m, 10–15 cerdos); vientres 10 (2×2 m, 1 cerda); sementales 2 (3×4 m, 10 cerdos) | Fases (m²/animal) | Engorda ≈ 1.0 m²/cerdo; vientres 4 m²; sementales 1.2 m². |
| Lactancia | 20 días | Fases | Destete a 25–30 d; lechón 5–7 kg. |
| Lechones vivos/parto; destetados/parto | 10–10.5; 8.5–10 | Supuestos (lechones/cerda) | Cuadro 2. |
| GDP 20–90 kg | 695 g/día | Fases (desarrollo y engorde) | Cuadro 2. |
| Conversión alimenticia 20–90 kg | 3.0 | Fases (consumo) | Cuadro 2. Consumo promedio = 3.0 × 0.695 ≈ 2.1 kg/día. |
| Rendimiento de canal a 90 kg | 75 % | Peso de salida 90 kg | Cuadro 2. |
| Alimentación gestantes | 1 kg mañana + 1 kg tarde = 2 kg/día | Fases | Sección Conversión alimenticia. |
| Alimentación lactantes | 3–4 kg/día | Fases | Se usa 3.5. |
| Alimentación engorda | Libre acceso, mezcla de granos (maíz, cebada, avena, trigo) + vitaminas y minerales | Fases | Dieta formulada por el productor; composición no registrada. |
| Clima / alojamiento | 20–40 °C; ventilación natural con cortinas | Fases (temp.) | Referencia del documento: >40 kg mantener <22 °C; lactantes 28–30 °C. |
| Espacios vitales (Sobalvarro 2015) | Lechón/destetado 0.15; 10–20 kg 0.20; >85 kg 0.65; reemplazo 1.65; cerda adulta 2.25; verraco 6 (10 en monta) m² | Comparar con corral real | Tu engorda (≈1.0 m²) supera el mínimo de 0.65 m². |
| Manejo de excretas | Heces como estiércol en pastos; limpieza diaria; cal + cloro al salir cada engorda | Contaminacion | No hay fosa ni laguna: manejo sólido. |
| Cadáveres | Entierro con cal a 2 m, a 1 km de la unidad | Faltantes_Normativa | Verificar permisos. |
| Mortalidad | 6 lechones por influenza en 2022 | Contaminacion (cadáveres) | Registro básico, no detallado. |
| Costo salud | $5,000–7,000/año actual; programa propuesto ≈ $8,000/año | Costos (opcional) | Pesos mexicanos, 2022. |
| FALTA: composición de la dieta | Proteína cruda y fósforo de la mezcla de granos | Balance de N y P | Es el dato que más cambia el resultado. Pídelo al productor o calcúlalo con tablas FEDNA. |
| FALTA: reparto real de hembras | Gestantes vs lactantes vs vacías | Lote_Calc | Aquí usé 87/13 como supuesto. |
| FALTA: reparto de la engorda | Desarrollo vs finalización | Lote_Calc | Aquí usé 60/60. |
| FALTA: agua | Consumo, fuente y litros de lavado | Supuestos | Ver Supuestos. |
| FALTA: superficie de pastos | Hectáreas donde se aplica el estiércol | Contaminacion | Para comparar con la superficie necesaria. |
| INCONSISTENCIA | 100 hembras pero 10 corrales de 1 cerda; 20 lechones pero camadas de ~10; '100–115 lechones/mes por 10 vientres' | Todo | Aclararlo con el productor o con tu equipo antes de entregar. |

## Hoja `Supuestos`

Rango con datos: 13 filas x 4 columnas.

| Supuestos globales |  |  |  |
| --- | --- | --- | --- |
| Cambia solo las celdas azules. |  |  |  |
| Parámetro | Valor | Unidad | Nota / fuente a verificar |
| Peso de un bulto de alimento | 40 | kg | Tu UPP usa su propia cosecha de granos; ajusta si compra en bulto. |
| Días del año | 365 | días | Inventario supuesto constante todo el año. |
| % del agua bebida que se pierde | 0.1 | fracción | Supuesto; medir en la UPP. |
| Agua de lavado | 2 | L/m²/día | Supuesto; tu UPP lava a diario (cal y cloro al salir cada engorda). Medir. |
| Límite de aplicación de N al suelo | 170 | kg N/ha/año | Referencia de la Directiva de Nitratos UE; verificar criterio aplicable en México/Puebla. |
| Retención de N en ganancia de peso | 0.025 | fracción de GDP | Típico 2.4–2.8 %; verificar (NRC 2012). |
| Retención de P en ganancia de peso | 0.0055 | fracción de GDP | Típico 0.5–0.6 %; verificar. |
| Factor N en proteína cruda | 6.25 | g PC / g N | Estándar. |
| Factor P → P2O5 | 2.29 | x | Conversión química estándar. |
| Lechones lactantes por cerda | 10 | lechones | Tu UPP: 10–10.5 vivos/parto (Cuadro 2). |

## Hoja `Fases`

Rango con datos: 20 filas x 15 columnas.

| Tabla base por fase productiva |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Verde = dato del proyecto 2022 (sin confirmar con el productor). Amarillo = falta/supuesto. Sin color = referencia típica no verificada. Precios = EJEMPLO (MXN). |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| Fase | Peso entrada (kg) | Peso salida (kg) | Días en fase | Consumo alimento (kg/animal/día) | Agua (L/animal/día) | Espacio (m²/animal) | Temp. ideal (°C) | Proteína cruda dieta (%) | Fósforo total dieta (%) | Excreta fresca (% peso vivo/día) | Precio alimento ($/kg) EJEMPLO | GDP (kg/día) | Conv. alimenticia | Origen y notas |
| Gestación (cerda) | 200 | 240 | 114 | 2 | 15 | 4 | 18 | 13.5 | 0.55 | 2.7 | 7.5 | =IFERROR((C5-B5)/D5,0) | N/A | UPP: consumo 2 kg/día (1 mañana + 1 tarde), corral individual 2×2 m. Resto referencia; peso de cerda sin dato. |
| Lactancia (cerda) | 240 | 225 | 20 | 3.5 | 25 | 4 | 22 | 17.5 | 0.65 | 6 | 9.5 | =IFERROR((C6-B6)/D6,0) | N/A | UPP: lactancia 20 d, consumo 3–4 kg/día (3.5), corral individual. Resto referencia. |
| Lechón predestete | 1.5 | 6 | 20 | 0.05 | 0.3 | 0 | 30 | 20 | 0.7 | 10 | 18 | =IFERROR((C7-B7)/D7,0) | N/A | UPP: destete 5–7 kg a 25–30 d (se usa 6 kg a 20 d). Espacio 0 (contado en lactancia). Temp. lactantes 28–30 °C (documento). |
| Destete / Posdestete | 6 | 20 | 35 | 0.6 | 1.5 | 0.15 | 26 | 19 | 0.65 | 10.6 | 13 | =IFERROR((C8-B8)/D8,0) | =IFERROR(E8*D8/(C8-B8),0) | Referencia. UPP vende los lechones a los 30–35 d; inventario 0 en Lote_Calc. Espacio 0.15 m² (Sobalvarro 2015). |
| Desarrollo / Crecimiento | 20 | 55 | 50 | 1.95 | 4.5 | 1 | 20 | 16.5 | 0.55 | 6.3 | 8.5 | =IFERROR((C9-B9)/D9,0) | =IFERROR(E9*D9/(C9-B9),0) | UPP: GDP 695 g/d y CA 3.0 entre 20 y 90 kg; ~50 d por tramo de 35 kg; corral ≈1 m²/cerdo. Consumo repartido para que CA global = 3.0. |
| Finalización / Engorde | 55 | 90 | 50 | 2.25 | 7 | 1 | 20 | 14.5 | 0.45 | 6.3 | 7.5 | =IFERROR((C10-B10)/D10,0) | =IFERROR(E10*D10/(C10-B10),0) | UPP: venta a 90 kg (canal 75 %). Consumo 2.25 kg/d; temp. recomendada >40 kg <22 °C (documento). |
| Sementales | 200 | 200 | 365 | 2.5 | 12 | 1.2 | 18 | 13.5 | 0.55 | 2.7 | 7.5 | =IFERROR((C11-B11)/D11,0) | N/A | UPP: 20 machos, 2 corrales de 3×4 m con 10 cada uno (1.2 m²). Sobalvarro recomienda 6 m²/verraco. Peso y consumo referencia. |
| Proteína cruda y fósforo (amarillo): tu UPP usa mezcla de granos + vitaminas y minerales sin composición registrada; los valores puestos son de dietas comerciales típicas. Sustitúyelos. |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| Fuentes para validar: |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| • Tu Proyecto Semestral 2022 (Rancho La Huamuchilera) y Sobalvarro (2015) para espacios. |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| • NRC 2012 – Nutrient Requirements of Swine. |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| • FEDNA – tablas de composición de ingredientes (para calcular PC y P de tu mezcla de granos). |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| • ASAE D384.2 – producción de excretas por tipo de cerdo. |  |  |  |  |  |  |  |  |  |  |  |  |  |  |

### Formulas de `Fases` (10)

| Celda | Formula | Valor guardado |
| --- | --- | --- |
| M5 | `=IFERROR((C5-B5)/D5,0)` | 0.350877192982456 |
| M6 | `=IFERROR((C6-B6)/D6,0)` | -0.75 |
| M7 | `=IFERROR((C7-B7)/D7,0)` | 0.225 |
| M8 | `=IFERROR((C8-B8)/D8,0)` | 0.4 |
| N8 | `=IFERROR(E8*D8/(C8-B8),0)` | 1.5 |
| M9 | `=IFERROR((C9-B9)/D9,0)` | 0.7 |
| N9 | `=IFERROR(E9*D9/(C9-B9),0)` | 2.78571428571429 |
| M10 | `=IFERROR((C10-B10)/D10,0)` | 0.7 |
| N10 | `=IFERROR(E10*D10/(C10-B10),0)` | 3.21428571428571 |
| M11 | `=IFERROR((C11-B11)/D11,0)` | 0 |

## Hoja `Lote_Calc`

Rango con datos: 15 filas x 11 columnas.

| Calculadora de alimento, agua, espacio y costo por inventario |  |  |  |  |  |  |  |  |  |  |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Inventario del proyecto 2022 (sin confirmar). Repartos supuestos en amarillo. |  |  |  |  |  |  |  |  |  |  |
| Fase | Nº animales (inventario) | Peso medio (kg) | Alimento (kg/día) | Alimento para completar la fase (kg) | Bultos/día | Costo alimento ($/día) | Costo para completar la fase ($) | Agua (L/día) | Superficie requerida (m²) | Biomasa (kg) |
| =Fases!A5 | 87 | =AVERAGE(Fases!B5,Fases!C5) | =B5*Fases!E5 | =B5*Fases!E5*Fases!D5 | =IFERROR(D5/Supuestos!$B$4,0) | =D5*Fases!L5 | =E5*Fases!L5 | =B5*Fases!F5 | =B5*Fases!G5 | =B5*C5 |
| =Fases!A6 | 13 | =AVERAGE(Fases!B6,Fases!C6) | =B6*Fases!E6 | =B6*Fases!E6*Fases!D6 | =IFERROR(D6/Supuestos!$B$4,0) | =D6*Fases!L6 | =E6*Fases!L6 | =B6*Fases!F6 | =B6*Fases!G6 | =B6*C6 |
| =Fases!A7 | 20 | =AVERAGE(Fases!B7,Fases!C7) | =B7*Fases!E7 | =B7*Fases!E7*Fases!D7 | =IFERROR(D7/Supuestos!$B$4,0) | =D7*Fases!L7 | =E7*Fases!L7 | =B7*Fases!F7 | =B7*Fases!G7 | =B7*C7 |
| =Fases!A8 | 0 | =AVERAGE(Fases!B8,Fases!C8) | =B8*Fases!E8 | =B8*Fases!E8*Fases!D8 | =IFERROR(D8/Supuestos!$B$4,0) | =D8*Fases!L8 | =E8*Fases!L8 | =B8*Fases!F8 | =B8*Fases!G8 | =B8*C8 |
| =Fases!A9 | 60 | =AVERAGE(Fases!B9,Fases!C9) | =B9*Fases!E9 | =B9*Fases!E9*Fases!D9 | =IFERROR(D9/Supuestos!$B$4,0) | =D9*Fases!L9 | =E9*Fases!L9 | =B9*Fases!F9 | =B9*Fases!G9 | =B9*C9 |
| =Fases!A10 | 60 | =AVERAGE(Fases!B10,Fases!C10) | =B10*Fases!E10 | =B10*Fases!E10*Fases!D10 | =IFERROR(D10/Supuestos!$B$4,0) | =D10*Fases!L10 | =E10*Fases!L10 | =B10*Fases!F10 | =B10*Fases!G10 | =B10*C10 |
| =Fases!A11 | 20 | =AVERAGE(Fases!B11,Fases!C11) | =B11*Fases!E11 | =B11*Fases!E11*Fases!D11 | =IFERROR(D11/Supuestos!$B$4,0) | =D11*Fases!L11 | =E11*Fases!L11 | =B11*Fases!F11 | =B11*Fases!G11 | =B11*C11 |
| TOTAL | =SUM(B5:B11) |  | =SUM(D5:D11) | =SUM(E5:E11) | =SUM(F5:F11) | =SUM(G5:G11) | =SUM(H5:H11) | =SUM(I5:I11) | =SUM(J5:J11) | =SUM(K5:K11) |
| Hembras 100 = 87 gestantes + 13 lactantes y engorda 120 = 60 + 60 son SUPUESTOS míos (amarillo). Los 20 lechones y 20 machos vienen de la Tabla 1 del documento. |  |  |  |  |  |  |  |  |  |  |
| 'Alimento para completar la fase' = animales × consumo diario × días de la fase. |  |  |  |  |  |  |  |  |  |  |

### Formulas de `Lote_Calc` (79)

| Celda | Formula | Valor guardado |
| --- | --- | --- |
| A5 | `=Fases!A5` | Gestación (cerda) |
| C5 | `=AVERAGE(Fases!B5,Fases!C5)` | 220 |
| D5 | `=B5*Fases!E5` | 174 |
| E5 | `=B5*Fases!E5*Fases!D5` | 19836 |
| F5 | `=IFERROR(D5/Supuestos!$B$4,0)` | 4.35 |
| G5 | `=D5*Fases!L5` | 1305 |
| H5 | `=E5*Fases!L5` | 148770 |
| I5 | `=B5*Fases!F5` | 1305 |
| J5 | `=B5*Fases!G5` | 348 |
| K5 | `=B5*C5` | 19140 |
| A6 | `=Fases!A6` | Lactancia (cerda) |
| C6 | `=AVERAGE(Fases!B6,Fases!C6)` | 232.5 |
| D6 | `=B6*Fases!E6` | 45.5 |
| E6 | `=B6*Fases!E6*Fases!D6` | 910 |
| F6 | `=IFERROR(D6/Supuestos!$B$4,0)` | 1.1375 |
| G6 | `=D6*Fases!L6` | 432.25 |
| H6 | `=E6*Fases!L6` | 8645 |
| I6 | `=B6*Fases!F6` | 325 |
| J6 | `=B6*Fases!G6` | 52 |
| K6 | `=B6*C6` | 3022.5 |
| A7 | `=Fases!A7` | Lechón predestete |
| C7 | `=AVERAGE(Fases!B7,Fases!C7)` | 3.75 |
| D7 | `=B7*Fases!E7` | 1 |
| E7 | `=B7*Fases!E7*Fases!D7` | 20 |
| F7 | `=IFERROR(D7/Supuestos!$B$4,0)` | 0.025 |
| G7 | `=D7*Fases!L7` | 18 |
| H7 | `=E7*Fases!L7` | 360 |
| I7 | `=B7*Fases!F7` | 6 |
| J7 | `=B7*Fases!G7` | 0 |
| K7 | `=B7*C7` | 75 |
| A8 | `=Fases!A8` | Destete / Posdestete |
| C8 | `=AVERAGE(Fases!B8,Fases!C8)` | 13 |
| D8 | `=B8*Fases!E8` | 0 |
| E8 | `=B8*Fases!E8*Fases!D8` | 0 |
| F8 | `=IFERROR(D8/Supuestos!$B$4,0)` | 0 |
| G8 | `=D8*Fases!L8` | 0 |
| H8 | `=E8*Fases!L8` | 0 |
| I8 | `=B8*Fases!F8` | 0 |
| J8 | `=B8*Fases!G8` | 0 |
| K8 | `=B8*C8` | 0 |
| A9 | `=Fases!A9` | Desarrollo / Crecimiento |
| C9 | `=AVERAGE(Fases!B9,Fases!C9)` | 37.5 |
| D9 | `=B9*Fases!E9` | 117 |
| E9 | `=B9*Fases!E9*Fases!D9` | 5850 |
| F9 | `=IFERROR(D9/Supuestos!$B$4,0)` | 2.925 |
| G9 | `=D9*Fases!L9` | 994.5 |
| H9 | `=E9*Fases!L9` | 49725 |
| I9 | `=B9*Fases!F9` | 270 |
| J9 | `=B9*Fases!G9` | 60 |
| K9 | `=B9*C9` | 2250 |
| A10 | `=Fases!A10` | Finalización / Engorde |
| C10 | `=AVERAGE(Fases!B10,Fases!C10)` | 72.5 |
| D10 | `=B10*Fases!E10` | 135 |
| E10 | `=B10*Fases!E10*Fases!D10` | 6750 |
| F10 | `=IFERROR(D10/Supuestos!$B$4,0)` | 3.375 |
| G10 | `=D10*Fases!L10` | 1012.5 |
| H10 | `=E10*Fases!L10` | 50625 |
| I10 | `=B10*Fases!F10` | 420 |
| J10 | `=B10*Fases!G10` | 60 |
| K10 | `=B10*C10` | 4350 |
| A11 | `=Fases!A11` | Sementales |
| C11 | `=AVERAGE(Fases!B11,Fases!C11)` | 200 |
| D11 | `=B11*Fases!E11` | 50 |
| E11 | `=B11*Fases!E11*Fases!D11` | 18250 |
| F11 | `=IFERROR(D11/Supuestos!$B$4,0)` | 1.25 |
| G11 | `=D11*Fases!L11` | 375 |
| H11 | `=E11*Fases!L11` | 136875 |
| I11 | `=B11*Fases!F11` | 240 |
| J11 | `=B11*Fases!G11` | 24 |
| K11 | `=B11*C11` | 4000 |
| B12 | `=SUM(B5:B11)` | 260 |
| D12 | `=SUM(D5:D11)` | 522.5 |
| E12 | `=SUM(E5:E11)` | 51616 |
| F12 | `=SUM(F5:F11)` | 13.0625 |
| G12 | `=SUM(G5:G11)` | 4137.25 |
| H12 | `=SUM(H5:H11)` | 395000 |
| I12 | `=SUM(I5:I11)` | 2566 |
| J12 | `=SUM(J5:J11)` | 544 |
| K12 | `=SUM(K5:K11)` | 32837.5 |

## Hoja `Contaminacion`

Rango con datos: 21 filas x 12 columnas.

| Excreta, nitrógeno, fósforo, efluente y superficie agrícola |  |  |  |  |  |  |  |  |  |  |  |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Balance: excretado = ingerido − retenido en ganancia. Aproximado. PC y P de la dieta son referencias (ver Fases). |  |  |  |  |  |  |  |  |  |  |  |
| Fase | Nº animales | Excreta fresca (kg/día) | N ingerido (g/animal/día) | N retenido (g/animal/día) | N excretado (g/animal/día) | P ingerido (g/animal/día) | P retenido (g/animal/día) | P excretado (g/animal/día) | N excretado grupo (kg/año) | P excretado grupo (kg/año) | Excreta + agua perdida + lavado (L/día) |
| =Fases!A5 | =Lote_Calc!B5 | =B5*Lote_Calc!C5*Fases!K5/100 | =Fases!E5*Fases!I5/100/Supuestos!$B$11*1000 | =MAX(0,Fases!M5*1000*Supuestos!$B$9) | =MAX(0,D5-E5) | =Fases!E5*Fases!J5/100*1000 | =MAX(0,Fases!M5*1000*Supuestos!$B$10) | =MAX(0,G5-H5) | =F5*B5*Supuestos!$B$5/1000 | =I5*B5*Supuestos!$B$5/1000 | =C5+Lote_Calc!I5*Supuestos!$B$6+Lote_Calc!J5*Supuestos!$B$7 |
| =Fases!A6 | =Lote_Calc!B6 | =B6*Lote_Calc!C6*Fases!K6/100 | =Fases!E6*Fases!I6/100/Supuestos!$B$11*1000 | =MAX(0,Fases!M6*1000*Supuestos!$B$9)+Fases!M7*1000*Supuestos!$B$9*Supuestos!$B$13 | =MAX(0,D6-E6) | =Fases!E6*Fases!J6/100*1000 | =MAX(0,Fases!M6*1000*Supuestos!$B$10)+Fases!M7*1000*Supuestos!$B$10*Supuestos!$B$13 | =MAX(0,G6-H6) | =F6*B6*Supuestos!$B$5/1000 | =I6*B6*Supuestos!$B$5/1000 | =C6+Lote_Calc!I6*Supuestos!$B$6+Lote_Calc!J6*Supuestos!$B$7 |
| =Fases!A7 | =Lote_Calc!B7 | =B7*Lote_Calc!C7*Fases!K7/100 | =Fases!E7*Fases!I7/100/Supuestos!$B$11*1000 | =MAX(0,Fases!M7*1000*Supuestos!$B$9) | =MAX(0,D7-E7) | =Fases!E7*Fases!J7/100*1000 | =MAX(0,Fases!M7*1000*Supuestos!$B$10) | =MAX(0,G7-H7) | =F7*B7*Supuestos!$B$5/1000 | =I7*B7*Supuestos!$B$5/1000 | =C7+Lote_Calc!I7*Supuestos!$B$6+Lote_Calc!J7*Supuestos!$B$7 |
| =Fases!A8 | =Lote_Calc!B8 | =B8*Lote_Calc!C8*Fases!K8/100 | =Fases!E8*Fases!I8/100/Supuestos!$B$11*1000 | =MAX(0,Fases!M8*1000*Supuestos!$B$9) | =MAX(0,D8-E8) | =Fases!E8*Fases!J8/100*1000 | =MAX(0,Fases!M8*1000*Supuestos!$B$10) | =MAX(0,G8-H8) | =F8*B8*Supuestos!$B$5/1000 | =I8*B8*Supuestos!$B$5/1000 | =C8+Lote_Calc!I8*Supuestos!$B$6+Lote_Calc!J8*Supuestos!$B$7 |
| =Fases!A9 | =Lote_Calc!B9 | =B9*Lote_Calc!C9*Fases!K9/100 | =Fases!E9*Fases!I9/100/Supuestos!$B$11*1000 | =MAX(0,Fases!M9*1000*Supuestos!$B$9) | =MAX(0,D9-E9) | =Fases!E9*Fases!J9/100*1000 | =MAX(0,Fases!M9*1000*Supuestos!$B$10) | =MAX(0,G9-H9) | =F9*B9*Supuestos!$B$5/1000 | =I9*B9*Supuestos!$B$5/1000 | =C9+Lote_Calc!I9*Supuestos!$B$6+Lote_Calc!J9*Supuestos!$B$7 |
| =Fases!A10 | =Lote_Calc!B10 | =B10*Lote_Calc!C10*Fases!K10/100 | =Fases!E10*Fases!I10/100/Supuestos!$B$11*1000 | =MAX(0,Fases!M10*1000*Supuestos!$B$9) | =MAX(0,D10-E10) | =Fases!E10*Fases!J10/100*1000 | =MAX(0,Fases!M10*1000*Supuestos!$B$10) | =MAX(0,G10-H10) | =F10*B10*Supuestos!$B$5/1000 | =I10*B10*Supuestos!$B$5/1000 | =C10+Lote_Calc!I10*Supuestos!$B$6+Lote_Calc!J10*Supuestos!$B$7 |
| =Fases!A11 | =Lote_Calc!B11 | =B11*Lote_Calc!C11*Fases!K11/100 | =Fases!E11*Fases!I11/100/Supuestos!$B$11*1000 | =MAX(0,Fases!M11*1000*Supuestos!$B$9) | =MAX(0,D11-E11) | =Fases!E11*Fases!J11/100*1000 | =MAX(0,Fases!M11*1000*Supuestos!$B$10) | =MAX(0,G11-H11) | =F11*B11*Supuestos!$B$5/1000 | =I11*B11*Supuestos!$B$5/1000 | =C11+Lote_Calc!I11*Supuestos!$B$6+Lote_Calc!J11*Supuestos!$B$7 |
| TOTAL | =SUM(B5:B11) | =SUM(C5:C11) |  |  |  |  |  |  | =SUM(J5:J11) | =SUM(K5:K11) | =SUM(L5:L11) |
| Resultados |  |  |  |  |  |  |  |  |  |  |  |
| Superficie agrícola necesaria para absorber el N (ha) |  |  | =IFERROR(J12/Supuestos!B8,0) |  |  |  |  |  |  |  |  |
| P2O5 excretado total (kg/año) |  |  | =K12*Supuestos!B12 |  |  |  |  |  |  |  |  |
| Excreta + agua perdida + lavado (m³/año) |  |  | =L12*Supuestos!B5/1000 |  |  |  |  |  |  |  |  |
| N excretado por cerdo de finalización en toda la fase (kg) |  |  | =F10*Fases!D10/1000 |  |  |  |  |  |  |  |  |
| En lactancia se suma a la cerda lo retenido por su camada; por eso el lechón predestete sale con N y P excretados ≈ 0. Tu UPP maneja excreta sólida como estiércol en pastos: el efluente líquido es solo una referencia. |  |  |  |  |  |  |  |  |  |  |  |
| Cuidado: PC y P de la dieta son de dietas comerciales; con tu mezcla de granos el N excretado real puede ser menor. |  |  |  |  |  |  |  |  |  |  |  |

### Formulas de `Contaminacion` (93)

| Celda | Formula | Valor guardado |
| --- | --- | --- |
| A5 | `=Fases!A5` | Gestación (cerda) |
| B5 | `=Lote_Calc!B5` | 87 |
| C5 | `=B5*Lote_Calc!C5*Fases!K5/100` | 516.78 |
| D5 | `=Fases!E5*Fases!I5/100/Supuestos!$B$11*1000` | 43.2 |
| E5 | `=MAX(0,Fases!M5*1000*Supuestos!$B$9)` | 8.7719298245614 |
| F5 | `=MAX(0,D5-E5)` | 34.4280701754386 |
| G5 | `=Fases!E5*Fases!J5/100*1000` | 11 |
| H5 | `=MAX(0,Fases!M5*1000*Supuestos!$B$10)` | 1.92982456140351 |
| I5 | `=MAX(0,G5-H5)` | 9.07017543859649 |
| J5 | `=F5*B5*Supuestos!$B$5/1000` | 1093.26336842105 |
| K5 | `=I5*B5*Supuestos!$B$5/1000` | 288.023421052632 |
| L5 | `=C5+Lote_Calc!I5*Supuestos!$B$6+Lote_Calc!J5*Supuestos!$B$7` | 1343.28 |
| A6 | `=Fases!A6` | Lactancia (cerda) |
| B6 | `=Lote_Calc!B6` | 13 |
| C6 | `=B6*Lote_Calc!C6*Fases!K6/100` | 181.35 |
| D6 | `=Fases!E6*Fases!I6/100/Supuestos!$B$11*1000` | 98 |
| E6 | `=MAX(0,Fases!M6*1000*Supuestos!$B$9)+Fases!M7*1000*Supuestos!$B$9*Supuestos!$B$13` | 56.25 |
| F6 | `=MAX(0,D6-E6)` | 41.75 |
| G6 | `=Fases!E6*Fases!J6/100*1000` | 22.75 |
| H6 | `=MAX(0,Fases!M6*1000*Supuestos!$B$10)+Fases!M7*1000*Supuestos!$B$10*Supuestos!$B$13` | 12.375 |
| I6 | `=MAX(0,G6-H6)` | 10.375 |
| J6 | `=F6*B6*Supuestos!$B$5/1000` | 198.10375 |
| K6 | `=I6*B6*Supuestos!$B$5/1000` | 49.229375 |
| L6 | `=C6+Lote_Calc!I6*Supuestos!$B$6+Lote_Calc!J6*Supuestos!$B$7` | 317.85 |
| A7 | `=Fases!A7` | Lechón predestete |
| B7 | `=Lote_Calc!B7` | 20 |
| C7 | `=B7*Lote_Calc!C7*Fases!K7/100` | 7.5 |
| D7 | `=Fases!E7*Fases!I7/100/Supuestos!$B$11*1000` | 1.6 |
| E7 | `=MAX(0,Fases!M7*1000*Supuestos!$B$9)` | 5.625 |
| F7 | `=MAX(0,D7-E7)` | 0 |
| G7 | `=Fases!E7*Fases!J7/100*1000` | 0.35 |
| H7 | `=MAX(0,Fases!M7*1000*Supuestos!$B$10)` | 1.2375 |
| I7 | `=MAX(0,G7-H7)` | 0 |
| J7 | `=F7*B7*Supuestos!$B$5/1000` | 0 |
| K7 | `=I7*B7*Supuestos!$B$5/1000` | 0 |
| L7 | `=C7+Lote_Calc!I7*Supuestos!$B$6+Lote_Calc!J7*Supuestos!$B$7` | 8.1 |
| A8 | `=Fases!A8` | Destete / Posdestete |
| B8 | `=Lote_Calc!B8` | 0 |
| C8 | `=B8*Lote_Calc!C8*Fases!K8/100` | 0 |
| D8 | `=Fases!E8*Fases!I8/100/Supuestos!$B$11*1000` | 18.24 |
| E8 | `=MAX(0,Fases!M8*1000*Supuestos!$B$9)` | 10 |
| F8 | `=MAX(0,D8-E8)` | 8.24 |
| G8 | `=Fases!E8*Fases!J8/100*1000` | 3.9 |
| H8 | `=MAX(0,Fases!M8*1000*Supuestos!$B$10)` | 2.2 |
| I8 | `=MAX(0,G8-H8)` | 1.7 |
| J8 | `=F8*B8*Supuestos!$B$5/1000` | 0 |
| K8 | `=I8*B8*Supuestos!$B$5/1000` | 0 |
| L8 | `=C8+Lote_Calc!I8*Supuestos!$B$6+Lote_Calc!J8*Supuestos!$B$7` | 0 |
| A9 | `=Fases!A9` | Desarrollo / Crecimiento |
| B9 | `=Lote_Calc!B9` | 60 |
| C9 | `=B9*Lote_Calc!C9*Fases!K9/100` | 141.75 |
| D9 | `=Fases!E9*Fases!I9/100/Supuestos!$B$11*1000` | 51.48 |
| E9 | `=MAX(0,Fases!M9*1000*Supuestos!$B$9)` | 17.5 |
| F9 | `=MAX(0,D9-E9)` | 33.98 |
| G9 | `=Fases!E9*Fases!J9/100*1000` | 10.725 |
| H9 | `=MAX(0,Fases!M9*1000*Supuestos!$B$10)` | 3.85 |
| I9 | `=MAX(0,G9-H9)` | 6.875 |
| J9 | `=F9*B9*Supuestos!$B$5/1000` | 744.162 |
| K9 | `=I9*B9*Supuestos!$B$5/1000` | 150.5625 |
| L9 | `=C9+Lote_Calc!I9*Supuestos!$B$6+Lote_Calc!J9*Supuestos!$B$7` | 288.75 |
| A10 | `=Fases!A10` | Finalización / Engorde |
| B10 | `=Lote_Calc!B10` | 60 |
| C10 | `=B10*Lote_Calc!C10*Fases!K10/100` | 274.05 |
| D10 | `=Fases!E10*Fases!I10/100/Supuestos!$B$11*1000` | 52.2 |
| E10 | `=MAX(0,Fases!M10*1000*Supuestos!$B$9)` | 17.5 |
| F10 | `=MAX(0,D10-E10)` | 34.7 |
| G10 | `=Fases!E10*Fases!J10/100*1000` | 10.125 |
| H10 | `=MAX(0,Fases!M10*1000*Supuestos!$B$10)` | 3.85 |
| I10 | `=MAX(0,G10-H10)` | 6.275 |
| J10 | `=F10*B10*Supuestos!$B$5/1000` | 759.93 |
| K10 | `=I10*B10*Supuestos!$B$5/1000` | 137.4225 |
| L10 | `=C10+Lote_Calc!I10*Supuestos!$B$6+Lote_Calc!J10*Supuestos!$B$7` | 436.05 |
| A11 | `=Fases!A11` | Sementales |
| B11 | `=Lote_Calc!B11` | 20 |
| C11 | `=B11*Lote_Calc!C11*Fases!K11/100` | 108 |
| D11 | `=Fases!E11*Fases!I11/100/Supuestos!$B$11*1000` | 54 |
| E11 | `=MAX(0,Fases!M11*1000*Supuestos!$B$9)` | 0 |
| F11 | `=MAX(0,D11-E11)` | 54 |
| G11 | `=Fases!E11*Fases!J11/100*1000` | 13.75 |
| H11 | `=MAX(0,Fases!M11*1000*Supuestos!$B$10)` | 0 |
| I11 | `=MAX(0,G11-H11)` | 13.75 |
| J11 | `=F11*B11*Supuestos!$B$5/1000` | 394.2 |
| K11 | `=I11*B11*Supuestos!$B$5/1000` | 100.375 |
| L11 | `=C11+Lote_Calc!I11*Supuestos!$B$6+Lote_Calc!J11*Supuestos!$B$7` | 180 |
| B12 | `=SUM(B5:B11)` | 260 |
| C12 | `=SUM(C5:C11)` | 1229.43 |
| J12 | `=SUM(J5:J11)` | 3189.65911842105 |
| K12 | `=SUM(K5:K11)` | 725.612796052632 |
| L12 | `=SUM(L5:L11)` | 2574.03 |
| D15 | `=IFERROR(J12/Supuestos!B8,0)` | 18.7627006965944 |
| D16 | `=K12*Supuestos!B12` | 1661.65330296053 |
| D17 | `=L12*Supuestos!B5/1000` | 939.52095 |
| D18 | `=F10*Fases!D10/1000` | 1.735 |

## Hoja `Faltantes_Normativa`

Rango con datos: 20 filas x 4 columnas.

| Datos que debes conseguir y normas a revisar |  |  |  |
| --- | --- | --- | --- |
| Normas: verifica vigencia y aplicabilidad (federal y Puebla) antes de citarlas. |  |  |  |
| Tipo | Dato / norma | Para qué sirve | Dónde conseguirlo |
| Dato UPP | Composición de la mezcla de granos (PC %, P %) y proporción de cada grano | Balance de N y P | Productor; tablas FEDNA para cada grano |
| Dato UPP | Cuántas hembras están gestantes, lactantes y vacías | Lote_Calc | Registros de servicios y partos de la UPP |
| Dato UPP | Reparto de la engorda por peso (desarrollo vs finalización) | Lote_Calc | Tablas por corral que lleva el productor |
| Dato UPP | Consumo de agua y fuente; litros de lavado diario | Supuestos | Medidor o estimación en visita |
| Dato UPP | Hectáreas de pasto donde se aplica el estiércol y su manejo (frecuencia, almacenamiento) | Comparar con superficie necesaria | Preguntar al productor |
| Dato UPP | Peso real de cerdas y sementales | Fases | Báscula o estimación |
| Dato UPP | Aclarar 100 hembras vs 10 corrales de 1 cerda, y lechones 20 vs camadas ~10 | Coherencia de inventario | Productor / equipo de trabajo |
| Norma | NOM-001-SEMARNAT-2021: descargas de aguas residuales | Aguas de lavado | DOF / SEMARNAT |
| Norma | NOM-087-SEMARNAT-SSA1-2002: residuos peligrosos biológico-infecciosos | Agujas, vacunas | DOF |
| Norma | NOM-061-ZOO-1999: alimentos para consumo animal | Alimento y aditivos | DOF / SENASICA |
| Norma | NOM-051-ZOO-1995: trato humanitario en la movilización de animales | Transporte (0.45 m²/cerdo de 100 kg, citada en tu documento) | DOF |
| Norma | NOM-064-ZOO-2000: clasificación y prescripción de fármacos veterinarios | Medicamentos (citada en tu documento) | DOF |
| Marco | LGEEPA y Ley de Aguas Nacionales | Marco ambiental | Textos oficiales |
| Marco | Buenas prácticas pecuarias en porcinos (SENASICA) | Lista de cumplimiento | SENASICA |
| Marco | Normatividad ambiental del estado de Puebla | Requisitos locales | Autoridad ambiental estatal; confirmar con el profesor |
| Dato UPP | Confirmar con el productor cuáles datos del proyecto 2022 son reales (inventario, corrales, alimentación, pesos, GDP, CA, camada) | Poder presentar el caso como real o rotularlo ilustrativo | Llamada corta con el dueño del rancho |

## Hoja `Mitigacion`

Rango con datos: 10 filas x 4 columnas.

| Medidas de mitigación y el dato que necesitas para cuantificarlas |  |  |  |
| --- | --- | --- | --- |
| Problema | Medida | Efecto esperado | Dato necesario para cuantificar |
| Exceso de N | Ajustar la proteína de la mezcla de granos y complementar con aminoácidos si se requiere | Menos N excretado | PC % actual vs. requerida por fase |
| Exceso de P | Fitasa en la dieta | Menos P excretado | P % de la mezcla; si ya usa fitasa |
| Volumen de agua en excreta | Revisar bebederos, lavado a presión | Menos efluente | Agua medida vs. estimada |
| Almacenamiento de estiércol | Compostaje o estercolero cubierto antes de aplicar a pastos | Menos olor, moscas y escurrimiento | Cuánto estiércol se acumula y dónde |
| Moscas y olor (clima cálido) | Manejo frecuente de estiércol, mosquiteros, control de larvas | Menos vectores | Presencia actual (tu documento: moscas altas) |
| Sobreaplicación al suelo | Plan de aplicación según superficie y cultivo | Evita lixiviación de nitratos | ha de pasto; análisis de suelo |
| Cadáveres | Entierro con cal a 2 m lejos de agua (ya lo hacen) | Evita contaminar agua subterránea | Distancia a pozos y cauces; permisos |
