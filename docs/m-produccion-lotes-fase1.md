# Produccion animal: lotes, registros y eventos (fase 1)

Estado: esquema aplicado en Supabase Pruebas el 12 de noviembre de 2026 con
`supabase/migrations/20261112000100_produccion_lotes.sql`. La app Flutter aun no lo
consume y no se crearon clinicas ni registros de prueba.

## Que resuelve

Un solo modelo para cerdos, postura y las especies nuevas: columnas nativas para lo
comun de todo lote (clinica, fechas, especie, proposito, cabezas) y JSONB para las
metricas propias de cada especie. No hay una tabla por especie ni una migracion por
especie nueva.

## Correcciones al borrador original

1. `clinic_id` obligatorio y RLS. El borrador solo tenia `id`; sin `clinic_id` los lotes
de todas las clinicas quedarian en la misma bolsa y la politica de acceso no tendria
que evaluar. Es el cambio que bloqueaba la propuesta.
2. `especie` y `proposito` separados. `bovino_leche` y `bovino_carne` mezclan animal y
destino, impiden registrar doble proposito y obligan a un `ALTER TYPE` (irreversible)
por cada especie nueva. Ahora `especie` y `proposito` son dos columnas con una tabla
puente que solo admite combinaciones validas.
3. Catalogo por fila en lugar de `ENUM`. Agregar una especie es un `INSERT` en
`produccion_especies` y su lista de metricas, sin tocar el tipo ni reescribir la tabla.
4. Historial diario en `produccion_registros`, no en el lote. Un JSONB dentro de
`lotes_produccion` se sobrescribe: no habria serie de litros, huevos o pH. El registro
diario es unico por `(lote_id, fecha)` y el upsert es idempotente.
5. Eventos sanitarios en tabla propia. "Vacas con mastitis" es un evento, no una
metrica: va a `produccion_eventos` con `tipo='sanitario'` y `subtipo`, indexado, para
poder cruzarlo despues con tratamientos y retiros. En JSONB perderia restricciones.
6. Contrato JSONB validado. `produccion_metricas` define por especie las claves
permitidas, su unidad y su rango; un trigger rechaza claves ajenas, valores no
numericos y rangos imposibles. Sin eso, "buscar dentro del JSON sin perder
rendimiento" no se sostiene.
7. `gen_random_uuid()` (pgcrypto) en lugar de `uuid_generate_v4()`.

## Tablas

- `produccion_especies`: `code`, `nombre`, `grupo` (mamifero/ave/pez/crustaceo/insecto).
- `produccion_especies_propositos`: combinaciones validas especie x proposito.
- `produccion_metricas`: `especie`, `clave`, `etiqueta`, `unidad`, `minimo`, `maximo`.
- `lotes_produccion`: `clinic_id`, `codigo`, `nombre`, `especie`, `proposito`, `sistema`,
  `fecha_inicio`, `fecha_fin`, `cabezas`, `identificador_hato`, `estado`, `atributos`
  (JSONB estatico: raza, nave, dieta base), `version`.
- `produccion_registros`: metricas del dia por lote, unicas por `(lote_id, fecha)`.
- `produccion_eventos`: sanitarios, mortalidad, pesajes, traslados, sacrificio y otros.

Claves sembradas: `alimento_kg`, `peso_promedio_g` y `temperatura_c` para todas las
especies; `leche_litros`, `grasa_pct`, `proteina_pct`, `lana_kg`, `peso_total_kg`,
`huevos_total`, `huevos_roto`, `peso_huevo_g`, `ph_agua`, `oxigeno_mg_l`, `biomasa_kg`,
`miel_kg` y `peso_colmena_kg` donde aplica.

## Acceso y escritura

Lectura directa por PostgREST con RLS: cualquier miembro de la clinica ve sus lotes,
registros y eventos; nadie sin membresia ve filas. Las tablas no admiten `INSERT`
directo del cliente. La escritura pasa por tres RPC, todas con recibo idempotente y
auditoria en `audit_log`:

- `produccion_lote_guardar(p_clinic, p_data jsonb, p_operation)` — admin o MVZ.
- `produccion_registro_guardar(p_clinic, p_lote, p_fecha, p_metricas, p_notas, p_operation)` — admin, MVZ o auxiliar.
- `produccion_evento_guardar(p_clinic, p_lote, p_fecha, p_tipo, p_subtipo, p_animales, p_detalle, p_operation)`.

Reglas: `fecha <= current_date`; un lote cerrado no acepta registros; la especie de un
lote con registros no se puede cambiar; `tipo='sanitario'` exige `subtipo`.

## Consultas utiles

```sql
-- Vacas con mastitis en la clinica
select l.codigo, e.fecha, e.animales_afectados, e.detalle
from public.produccion_eventos e
join public.lotes_produccion l on l.id = e.lote_id and l.clinic_id = e.clinic_id
where e.clinic_id = $1 and e.tipo = 'sanitario' and lower(e.subtipo) = 'mastitis'
order by e.fecha desc;

-- Litros de leche por mes
select date_trunc('month', r.fecha) as mes,
       sum((r.metricas->>'leche_litros')::numeric) as litros
from public.produccion_registros r
where r.clinic_id = $1 and r.metricas ? 'leche_litros'
group by 1 order by 1;
```

## Flutter

Los formularios se construyen desde `produccion_metricas` (etiqueta, unidad, minimo y
maximo por especie), no con claves escritas en el cliente. El cliente envia `metricas`
como mapa numero y recibe el error del servidor cuando el contrato no se cumple
(`metricas_invalidas`, `produccion_metricas_invalidas`, `lote_closed`).

## Limites y pendientes

- Los permisos son por rol (`admin`, `mvz`, `auxiliar`). Falta migrar a codigos
explicitos del catalogo de permisos (`production.read`, `production.write`) cuando se
extienda esa base; hoy `permission_effective` exige una concesion y dejaria sin acceso
a todos.
- Sin conversion de unidades, sin resumen de indicadores y sin UI/repositorio Flutter.
- Sin tratamientos, retiros ni vinculo con inventario (fase 2).
- Sin animales individuales: el modelo es por lote, como el borrador original.
- No se ejecuto `private.beta_install_guards()` para no reescribir triggers de todas las
tablas; con `enforcement_enabled=false` no aplica.

## Reversion

```sql
drop function if exists public.produccion_evento_guardar(uuid,uuid,date,text,text,integer,jsonb,text);
drop function if exists public.produccion_registro_guardar(uuid,uuid,date,jsonb,text,text);
drop function if exists public.produccion_lote_guardar(uuid,jsonb,text);
drop function if exists private.produccion_registro_validar();
drop function if exists private.produccion_metricas_ok(text,jsonb);
drop table if exists public.produccion_eventos, public.produccion_registros,
  public.lotes_produccion, public.produccion_metricas,
  public.produccion_especies_propositos, public.produccion_especies cascade;
```
