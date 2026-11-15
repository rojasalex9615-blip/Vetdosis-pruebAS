# M15: aves de postura

## Alcance

Módulo aditivo para registrar parvadas de postura por clínica. No modifica
tablas, políticas ni funciones anteriores y no borra datos. Los cálculos de
capacidad e incubación siguen siendo herramientas locales (`AvicultureScreen`,
`IncubationScreen`); este módulo añade los registros del ciclo productivo.

## Tablas (todas con RLS y sin privilegios para `anon`/`authenticated`)

| Tabla | Contenido |
|---|---|
| `public.aviculture_references` | Catálogo de capacidad/espacio: 12 filas del CSV más 3 pendientes sin valor |
| `public.aviculture_equipment_references` | 7 equipos con aves por unidad, nota y fuente |
| `public.aviculture_houses` | Casetas/galpones por clínica, sistema, capacidad, archivo |
| `public.aviculture_flocks` | Parvadas: código, caseta, línea, inicio, aves iniciales, estado |
| `public.aviculture_production_records` | Un registro por parvada y día: huevos, descartes, bajas, alimento, peso, agua |
| `public.aviculture_flock_events` | Vacunación, tratamiento, desparasitación, pesaje, alimentación, inspección |

Los datos del catálogo conservan el estado `sin_verificar` y su fuente textual;
los tres parámetros sin fuente quedan con mínimo, máximo y unidad nulos. No se
corrigieron ni extrapolaron valores desde los apuntes.

## RPC

- `avi_workspace(p_clinic)` — snapshot: catálogo, casetas, parvadas con
  indicadores, últimos 400 registros y 200 eventos. Devuelve `can_write`.
- `avi_house_save(p_clinic,p_id,p_version,p_data,p_operation)`
- `avi_flock_save(...)` — crear, editar y cerrar ciclo.
- `avi_production_save(...)` — alta y corrección del día.
- `avi_event_save(...)` — eventos con retiro de huevo opcional.

Cada escritura es idempotente (`p_operation` de 48 hex), valida la versión
contra ediciones concurrentes, deja constancia en `public.audit_log` y usa el
recibo transaccional existente (`private.vet_receipt`).

## Roles

- Lectura: cualquier integrante de la clínica.
- Escritura de registros, eventos y casetas: `admin`, `mvz`, `auxiliar`.
- Crear, editar o cerrar parvadas: `admin` y `mvz`.

Sin membresía la función responde `access_denied`; sin rol suficiente,
`write_role_required` o `lead_role_required`.

## Indicadores

Se calculan en el servidor con los registros existentes: semana de vida, aves
vivas (iniciales − bajas), mortalidad acumulada y porcentaje, huevos totales,
alimento total, postura del último día (`huevos / aves vivas × 100`) y gramos
por ave y día. Son indicadores operativos: no acreditan bienestar ni
certificación.

## Cliente Flutter

- `lib/modules/aviculture/domain/aviculture_records.dart`
- `lib/modules/aviculture/domain/aviculture_records_repository.dart`
- `lib/modules/aviculture/data/supabase_aviculture_records_repository.dart`
- `lib/modules/aviculture/presentation/aviculture_records_view_model.dart`
- `lib/modules/aviculture/presentation/aviculture_records_screen.dart`
- Entrada: Producción y grandes especies → Aves → Postura →
  «Parvadas, casetas y producción».

La pantalla es autocontenida, como las demás herramientas avícolas: recibe el
espacio activo y crea su repositorio. Solo refleja `can_write`; cada operación
se autoriza de nuevo en el servidor.

## Aplicación

1. Revisar privilegios de la base existente.
2. Ejecutar `supabase/adaptations/existing_aviculture_m15.sql` una sola vez.
3. Verificar en Supabase que las seis tablas existen, con RLS activo y sin
   privilegios para `anon`/`authenticated`.
4. Compilar el cliente de esta rama.

No se aplicó nada sobre el proyecto remoto desde esta sesión.

## Pruebas

`supabase/tests/aviculture_postura.sql` es una prueba aislada, autocontenida,
con dependencias sintéticas (`auth.uid()`, membresías, recibo de operación).
Cubre: catálogo instalado, aislamiento entre clínicas, idempotencia de casetas,
control de versión, código de parvada duplicado, fechas inválidas, registro
duplicado, mortalidad mayor que las aves vivas, indicadores, edición
concurrente, retiro de huevo, cierre de ciclo, protección de aves iniciales con
registros, rol auxiliar sin permiso para crear parvadas y ausencia de
privilegios directos.

```sh
supabase/tests/run.sh aviculture
```

La prueba se ejecutó sobre PostgreSQL 17 local con un binario portátil. **No**
se ejecutó la suite completa del repositorio, ni `flutter analyze`/`flutter
test`, ni se aplicó la migración al proyecto real de Supabase.
