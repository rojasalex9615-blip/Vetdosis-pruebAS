# VetDosis Pro — Mapa de arquitectura y estados, corte verificado

**Corte: 11 de noviembre de 2026.** Sustituye al corte «Noviembre 2026» del
*Master Control Document* en los puntos marcados **CORREGIDO**; el resto de ese
documento (el flujo P1, la matriz de aislamiento y las tres pantallas
propuestas) sigue válido y no se repite aquí.

**Cómo se comprobó cada estado.** Lectura del código del repositorio y consulta
de **solo lectura** al proyecto Supabase **Pruebas** (`wtrelwtztkddfktrfdpb`,
PostgreSQL 17.11.0.003): `pg_proc`, `pg_class`, `pg_constraint` y conteos
agregados. **No se ejecutó DDL, no se leyó ningún registro clínico ni de
cuenta, y no se aplicó nada.** Lo que no pude comprobar se dice así, no se
rellena.

---

## 1. La regla de oro no cambia

> **Calcular ≠ Prescribir ≠ Dispensar ≠ Administrar**

Está sostenida en el servidor, no solo en la interfaz: `private.permission_require`,
`private.clinical_professional_at` y `private.permission_immutable` separan quien
calcula de quien atestigua, y los registros clínicos no se editan ni se borran
(se corrigen con `replaces_id` y motivo).

---

## 2. Contratos del servidor: los nombres reales

**CORREGIDO.** La columna «Dependencias Críticas» del documento anterior nombra
tres contratos que **no existen** en el servidor. Si alguien programa contra
esos nombres, falla en ejecución:

| El documento decía | En Pruebas |
|---|---|
| `get_user_clinics` | **no existe** → `app_module_workspace`, `workspace_memberships` |
| `process_pos_sale` | **no existe** → `inv_sale_post_v2` |
| `close_cash_shift` | **no existe** → `inv_cash_move` |

Hay **334 funciones** en el esquema `public`. El acceso es solo por RPC: las
tablas viven en `private` y están revocadas, justamente para que toda lectura y
escritura pase por una función que comprueba permisos.

Reparto por módulo de esas 334:

| Módulo | RPC |
|---|---:|
| M6 receta y formatos | 75 |
| M8 inventario y caja | 41 |
| M9 agenda y operaciones | 31 |
| M5 hospitalización | 31 |
| M1 núcleo y clínicas | 22 |
| M2 permisos | 17 |
| M12 IA | 12 |
| respaldo y restauración | 11 |
| M4 expediente | 4 |
| M3 dosis y referencias | 1 |
| **M15 laboratorio** | **0** (sin aplicar) |
| otros | 89 |

Que M3 tenga una sola función no es una carencia: el cálculo de dosis vive en el
cliente a propósito, y del servidor solo necesita la biblioteca de referencias
(`reference_review_list`).

---

## 3. Matriz de estados, corregida

Tres estados se distinguen y antes se mezclaban: **escrito** (código en el
repositorio), **aplicado** (el contrato existe en Pruebas) y **probado en
teléfono** (nadie lo ha hecho todavía con nada de esto).

| Módulo | Estado anterior | Estado verificado 11/11 |
|---|---|---|
| **M1 · Núcleo y clínicas** | 🟡 pendiente limpiar caché al cambiar clínica | 🟡 igual. Escrito y aplicado (22 RPC). La purga de caché al conmutar sede sigue pendiente de comprobar en dispositivo |
| **M2 · Acceso y permisos** | 🔴 auditoría RLS pendiente | 🟡 **CORREGIDO**: sí hay permisos efectivos en servidor (17 RPC, `permission_effective`, `permission_event`, beta y permisos con interruptor propio). La auditoría de `anon` sigue abierta, y hay una rama que va a eso: `fix/security-anon-grants-20261110`, **solo en GitLab** |
| **M3 · Dosis y catálogo** | 🟢 requiere auditoría de concentraciones | 🟡 **CORREGIDO**: la auditoría no es un pendiente futuro, está en marcha y con datos cargados. 2 574 filas importadas, **ninguna validada** (`review_state = 'pending'`) |
| **M4 · Expedientes (SOAP)** | 🟢 falta sincronización offline | 🟡 igual. Escrito y aplicado. El trabajo sin conexión sigue anunciado como «próximamente» en la propia pantalla de bienvenida |
| **M5 · Hospitalización** | 🟡 falta enganche con dispensación | 🟡 igual (31 RPC aplicados) |
| **M6 · Prescripción Rx** | 🟡 falta firma remota y storage | 🟡 **matizado**: no falta código, falta **desplegar**. `13X_storage_media.sql` no está aplicado; sin él la pantalla ofrece subir y el servidor rechaza |
| **M8 · Inventario y POS** | 🟡 faltan contratos RPC de devoluciones | 🟢 **CORREGIDO**: `inv_sale_return_v3`, `inv_sale_return_workspace` e `inv_sale_collect` están aplicados, con abonos, devoluciones parciales y recuperación de comisiones |
| **M12 · Copiloto IA** | 🟡 falta proxy de Edge Function | 🟡 **matizado**: hay funciones de borde y 12 RPC. Lo que falta es `13Y_ai_key_rotation.sql`, sin aplicar: la llave no se puede rotar sin tocar la base a mano |
| **M15 · Laboratorio** | *(no figuraba)* | 🔴 **NUEVO**: escrito, probado en PostgreSQL local, **sin aplicar**. 15M y 15N pendientes |
| **Escáner OCR de etiquetas** | 🟡 no asigna dosis automática (por diseño) | 🟡 igual, y el «por diseño» se conserva |
| **Escáner de código de barras** | 🟡 distinto del OCR | 🟡 igual |

---

## 4. Lo único que separa esto de «usable»: cinco archivos

No es código faltante. Es despliegue, y necesita tu autorización una por una.

| Orden | Archivo | Si no se aplica |
|---:|---|---|
| 1 | `supabase/proposed/13X_storage_media.sql` | Fotos y adjuntos: la pantalla ofrece subir y el servidor rechaza |
| 2 | `supabase/proposed/13Y_ai_key_rotation.sql` | La llave del asistente no rota |
| 3 | `supabase/proposed/15M_lab_results.sql` | El botón de analíticas del expediente falla al abrir |
| 4 | `supabase/proposed/15N_lab_reference_library_bridge.sql` | 15M marca «Sin rango de referencia» en todos los analitos |
| 5 | `supabase/adaptations/appointment_kind_field_visit_v1.sql` | **Va antes de publicar la app**: al revés, «Visita a campo o granja» se rechaza al guardar |

`15N` va después de `15M`. El resto son independientes. El orden completo de los
83 archivos de la cadena, con el estado de cada uno, está en el `README.md` de
esta misma carpeta.

---

## 5. Valores de referencia: qué van a ver las clínicas

| | Filas |
|---|---:|
| Importadas en total | 2 574 |
| Resuelven como referencia de **laboratorio** | 403 |
| Resuelven como **constantes fisiológicas** | 301 |
| Canino · laboratorio | 113 |
| Felino · laboratorio | 103 |
| Canino / Felino · constantes | 13 / 11 |
| Productos comerciales con etiqueta | 1 384 (531 regímenes) |

Entrada: **Calculadora → «Referencias fisiológicas» / «Referencias de
laboratorio»**, por `reference_review_list`, que **ya está aplicada**. Exige rol
`admin` o `mvz` y permiso `clinical.read`.

Tres cosas que la clínica revisora debe saber:

1. **Ninguna fila está validada.** Las 2 574 están en `pending`, con la nota
   «Imported verbatim; not clinically validated».
2. **Las fuentes son de la importación**, no un libro de texto: en canino y
   felino predominan `labforvets.com` y `riomartinez.com`. Cada intervalo se
   muestra con su fuente para poder aceptarlo, corregirlo o rechazarlo.
3. **Donde dos fuentes no coinciden se muestran las dos**, y el servidor no
   emite veredicto: una prueba lo fija. Si el archivo de origen avisa de otro
   intervalo sin darlo, el aviso viaja con la fuente y **no** se inventa un
   segundo rango.

Las unidades vienen como en el archivo de origen (`uL` para cuentas absolutas,
`10^6/uL` para eritrocitos). Normalizarlas es decisión de la revisión.

---

## 6. Lo que nadie ha comprobado

- **Nada se ha probado en un teléfono.** Ni de los cinco pendientes ni de lo ya
  aplicado. Lo verde de arriba es «aplicado en Pruebas» y «pruebas de contrato
  en verde», no «un MVZ lo usó».
- **El APK de GitHub falla en `main`.** El workflow «Compilar APKs — main» muere
  a los ~10 segundos en `0057138` y en `fb29b2a`: firma de secreto ausente, no
  de fallo de código. GitLab sigue siendo el que compila.
- **La auditoría de RLS para `anon`** sigue abierta (ver M2).
