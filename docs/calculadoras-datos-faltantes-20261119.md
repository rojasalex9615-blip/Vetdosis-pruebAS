# Calculadoras sin datos y tablas ya existentes en Supabase

Inventario verificado contra el proyecto `wtrelwtztkddfktrfdpb` el 2026-11������������������������������������������������������������������������������������������������������������������������������姞'MD
echo "--- corrigiendo ---"
cat > docs/calculadoras-datos-faltantes-20261119.md <<'MD'
# Calculadoras sin datos y tablas ya existentes en Supabase

Inventario verificado el 2026-11-19 contra el proyecto `wtrelwtztkddfktrfdpb`
(«Pruebas»). No se modificó ningún dato para hacer este inventario.

## 1. Herramientas que muestra «Cálculos clínicos»

El desplegable de la app tiene nueve entradas: seis con fórmula y cuatro
herramientas de consulta.

| Herramienta | Qué le falta |
| --- | --- |
| Fluidoterapia (`fluids`) | Nada: la fórmula es dimensional y no necesita datos. |
| Infusión continua (`cri`) | Nada para calcular; le falta la tabla de fármacos con dosis. |
| Producción: por cabeza y lote (`herd`) | Nada: aritmética. |
| Producción: agua (`water`) | Nada: aritmética. |
| Producción: alimento (`feed`) | Nada: aritmética. |
| Ajuste pediátrico/geriátrico (`adjustment`) | Nada: aritmética. |
| Protocolos por etapas (`protocols`) | **Sin datos.** `assets/clinical/calculations.v1.json` trae `referencias: []`. |
| Constantes fisiológicas (`vitals`) | Ya resuelto: lee de Supabase (`reference_review_list`). |
| Peso metabólico en exóticos (`metabolic`) | **Sin datos.** |
| Tiempos de retiro (`withdrawals`) | **Sin datos**, aunque las tablas de Virbac ya tienen 63 filas. |

El propio asset lo declara: `"Sin datos clínicos precargados"` y
`"referencias": []`. Las seis calculadoras con fórmula funcionan porque solo
hacen operaciones dimensionales.

## 2. Tablas que ya existen y no se están usando

Ninguna de estas tablas tiene una función que las lea, y todas tienen RLS
activo sin permiso para `authenticated`. Están cargadas pero desconectadas.

| Tabla (`private.`) | Filas | Para qué sirve |
| --- | --- | --- |
| `vetdosis_virbac_productos` | 34 | Fichas de producto Virbac. |
| `vetdosis_virbac_producto_dosis` | 64 | **Dosis por especie, vía y frecuencia.** 24 con dosis por kg; 9 marcadas para revisar. |
| `vetdosis_virbac_producto_dosis_activos` | 47 | Qué principio activo lleva cada dosis. |
| `vetdosis_virbac_producto_tiempos_espera` | 63 | **Tiempos de retiro** por especie y matriz; 6 con uso prohibido. |
| `vetdosis_qwen_farmacos_revision` | 127 | Fármacos por principio activo. |
| `vetdosis_qwen_dosis_revision` | 54 | Dosis por principio activo. |
| `vetdosis_indice_principios_revision` | 94 | Índice de principios activos. |
| `vetdosis_qwen_marcas_revision` | 30 | Tabla por nombre comercial. |
| `vetdosis_indice_ingredientes_comerciales_revision` | 499 | Ingredientes comerciales. |
| `vetdosis_relacion_productos_principios_revision` | 1 470 | Relación producto ↔ principio activo. |

Ejemplo real de `vetdosis_virbac_producto_dosis`: Borgal, porcino, IM,
1 ml / 16 kg, cada 24 h. Ejemplo de tiempos de espera: Borgal, bovino, carne,
10 días.


## 2 bis. Tabla unificada de fabricante por nombre comercial

Corrección de un error mío anterior: primero creé la vista
`commercial_product_dose_unified` uniendo solo el inventario comercial y
Virbac. Era una **tabla paralela**. Ya existían dos catálogos de fabricante que
la app expone por separado:

| Fuente | Filas | Nombres | La lee |
| --- | --- | --- | --- |
| `private.vetdosis_inventario_comercial_revision` | 687 | 687 | `review_catalog_list` |
| `raw_intake_rows`, hoja `Pautas` | 1.197 | 693 | `review_pauta_list` |
| Tablas Virbac (5 tablas) | 34 productos / 64 dosis | 34 | ninguna función |

Solo 81 nombres se solapan entre las dos primeras y Virbac no aparece en
pautas: son fuentes casi disjuntas, no duplicados.

La vista buena es `vetdosis_reference_staging.vademecum_producto_comercial`:

- **1.833 filas, 1.297 nombres comerciales únicos, 91 laboratorios.**
- 370 filas con dosis por kg calculable; 1.246 con tiempo de retiro.
- Cuando un nombre está en inventario y en pauta, gana la pauta (trae especie,
  dosis por kg e intervalo) y hereda la concentración del inventario. Por eso
  el inventario aporta 572 fichas y no 653: **0 nombres duplicados entre
  fuentes**.
- Virbac entra por sus tablas estructuradas con sus 64 dosis y 49 tiempos de
  retiro, que antes nadie leía.
- `fuente` indica el origen de cada fila para poder rastrearla.
- Todo sale con `habilitado_en_app = false` y `estado_revision =
  'sin_verificar'`.

Ejemplo: PARAFEN SUSPENSIÓN 3 %, Aranda, ovinos y caprinos, 0,1667 mL/kg cada
24 h, retiro de carne 15 días.

Queda pendiente conectar esta vista a la calculadora por nombre comercial. Los
datos ya están unificados; falta la pantalla.

## 3. Lo que sí está conectado

- `reference_review_list` alimenta «Constantes fisiológicas», «Laboratorio» y,
  desde este cambio, «Vademécum por principio activo» (377 monografías).
- `review_catalog_list` alimenta el catálogo comercial de 662 fichas.
- `review_pauta_list` alimenta las 1 197 pautas, todas con
  `enabled_in_app = false`: se consultan, no calculan.
- `dose_personal_entries` alimenta la importación manual de farmacia, por
  clínica y por usuario. Es independiente del catálogo de la app.

## 4. Qué haría falta para cerrar cada hueco

1. **Tiempos de retiro**: es el hueco más barato. Las 63 filas ya están
   cargadas y limpias; solo falta una función de lectura con el mismo patrón de
   permisos que `reference_review_list` y una pantalla que la muestre.
2. **Protocolos por etapas y peso metabólico**: no hay tabla de origen. Hay que
   decidir la fuente antes de cargar nada.
3. **Dosis por principio activo en la calculadora**: las 377 monografías del
   vademécum ya se consultan, pero no alimentan cálculo. Para eso hace falta
   revisión MVZ que fije fármaco, especie, dosis, vía e intervalo. El
   encabezado del fármaco no es recuperable del OCR en 359 de 377 monografías.

## 5. Criterio

Ninguna de estas tablas modifica el catálogo de cálculo ni emite recetas. Se
muestran con su fuente para que el MVZ decida. Convertir una fila en regla de
cálculo exige revisión explícita.
