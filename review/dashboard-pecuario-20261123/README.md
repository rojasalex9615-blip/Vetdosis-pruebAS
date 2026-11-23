# Dashboard Pecuario: tarjetas, tira amarilla y datos de ejemplo

Tres cosas distintas en las dos capturas. Una ya estaba arreglada, dos no.

---

## 1. La tira amarilla y negra — ya estaba corregida

Los desbordes que se ven en la captura de los silos (la leyenda de la gráfica
y las filas «Autonomía: 5 días ⚠️ ¡URGENTE!») **se arreglaron en `f0b5935`**,
el primer commit de esta rama.

Lo comprobé en el historial: antes de ese commit la leyenda era

```dart
Row(mainAxisAlignment: MainAxisAlignment.center, ...)
```

que es exactamente lo que muestra la captura: un solo renglón que se sale. Hoy
es un `Wrap`, y las filas de silo ya llevan `Expanded` + `Flexible`.

**El APK que estás probando es anterior a ese commit.** Al reinstalarlo esas
tiras desaparecen. El auditor confirma 0 filas fuera de los 360 dp.

---

## 2. Las tarjetas desalineadas — corregido

Dos defectos reales, los dos vivos en el código actual.

### Las tarjetas de alerta bailaban entre sí

El `Row` de cada alerta usaba el centrado vertical por omisión. Como cada
alerta parte el texto en un número distinto de renglones, el icono y la
etiqueta de días caían a una altura **diferente en cada tarjeta**: en una
quedaban junto al título y en la siguiente junto al subtítulo. De ahí la
sensación de desalineación entre tarjetas.

Ahora van ancladas arriba (`CrossAxisAlignment.start`), así que icono, título
y días coinciden en todas sin importar cuánto texto haya.

### La cabecera de silos salía torcida

| | ancho |
| --- | --- |
| Título «Inventario en Silos y Autonomía» | 230 dp |
| Acción «Disparar pedido a planta» | 192 dp |
| Disponible en la tarjeta | **294 dp** |

Con `Expanded`, al título le quedaban 102 dp y caía en **3 renglones**
desiguales al lado de un botón centrado. La cuenta predice 3 y la captura
muestra 3. Ahora es un `Wrap`: el título conserva su ancho y la acción baja
sola cuando no cabe.

---

## 3. Los datos de ejemplo — corregido de raíz

Dijiste que los datos están en Supabase y salen de las calculadoras. Fui a
mirar el proyecto que usa la app (`wtrelwtztkddfktrfdpb`, «Pruebas», que es el
que apunta `build_channel.dart`):

| tabla | filas | qué es |
| --- | --- | --- |
| `lotes_produccion` | **0** | tus lotes |
| `produccion_registros` | **0** | lo que generan las calculadoras |
| `produccion_eventos` | **0** | vacunas, resguardos, partos |
| `produccion_metricas` | 45 | catálogo de referencia |
| `produccion_upp_fases` | 7 | referencia por fase |
| `produccion_especies` | 9 | catálogo de especies |

Las tablas de referencia tienen datos; **las tuyas están vacías**. Y aun así el
panel pintaba una granja de 480 vacas con silos al 71 % y una «Vaca #402».
Todo salía de `speciesDataCatalog`, un mapa fijo en el código. Ninguna de esas
tablas tenía cliente en Dart: solo `produccion_upp_fases` estaba conectada.

### Qué se hizo

**Capa de datos nueva**

- `domain/production_farm.dart` — modelos `FarmBatch`, `FarmEvent`,
  `FarmRecord`, `FarmMetricDef` y `FarmSnapshot`, más el contrato del
  repositorio.
- `data/supabase_production_farm_repository.dart` — lee las cuatro tablas,
  acotando siempre por `clinic_id` además de RLS.
- Enlazado desde `main.dart` → `app.dart` → `ProductionMenu` →
  `ProductionDashboard`.

**Traducción de especies.** El selector dice «Porcinos» pero la tabla guarda
`cerdo`; «Aves» son dos códigos, `gallina` y `pavo`. Sin esa traducción la
consulta no encontraría nada aunque hubiera lotes. Está en `codigosDeEspecie`
y tiene prueba propia. «Equinos» no es especie de producción en el catálogo, y
el panel lo dice en lugar de fingir.

**Tres estados, no uno.** El panel ahora distingue:

1. **cargando** — un indicador, no cifras;
2. **fallo de red** — «No se pudieron leer los datos», con reintento. Un corte
   de conexión no es una granja vacía y no deben confundirse;
3. **sin registros** — «Aún no hay datos de producción», explicando que
   aparecerán cuando des de alta un lote y las calculadoras guarden registros.

Cuando sí hay datos, pinta cabezas, lotes activos, los lotes reales y los
eventos próximos leídos de tus tablas.

**Se retiraron** las secciones que solo sabían pintar el catálogo de ejemplo
(retiros, KPIs financieros, curva, silos, instalaciones y calendario), tanto
del dashboard como del detalle de especie del menú, que tenía el mismo
problema. En cuanto esas métricas tengan tabla, se reconstruyen sobre datos
reales.

**Lo que se conservó a propósito:**

- Las **calculadoras** y el vademécum: no dependen de que haya lotes.
- Las **constantes fisiológicas** (`metrics.vitals`): son rangos de referencia
  por especie, no cifras de tu granja.
- La **dosificación masiva**, que colgaba de una sección retirada. Es una
  calculadora, no un dato inventado, así que se movió a Herramientas.

### Pruebas

`test/production_dashboard_test.dart` fijaba el comportamiento viejo: exigía
ver «Pulso Financiero», «Mapa Operativo» y demás. Estaba certificando el error.
Se reescribió para exigir lo contrario:

- sin registros se dice, y las cifras inventadas **no** aparecen
  (`Silo Ensilado Maíz`, `Vaca #402`, `Vaquillas de Reemplazo`);
- un fallo de red no se confunde con una granja vacía;
- con lotes y eventos de mentira, los pinta;
- cada especie pide sus códigos correctos;
- las calculadoras siguen ahí sin datos de granja.

---

## Pendiente de tu lado

Aquí no hay Flutter, así que nada de esto se compiló. Queda por validar:

- `flutter analyze`
- `flutter test` — en especial `test/production_dashboard_test.dart`
- Reinstalar el APK: confirma de paso que las tiras amarillas ya no están.

Y una decisión tuya: las métricas financieras (costo por litro, conversión
alimenticia), los silos y las instalaciones **no tienen tabla todavía**. Si
quieres que vuelvan, hay que definir de dónde salen — probablemente derivadas
de `produccion_registros`. Dime y las construyo sobre datos reales.
