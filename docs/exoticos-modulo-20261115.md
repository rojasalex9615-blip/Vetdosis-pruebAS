# Exóticos · referencias de mamíferos pequeños (candidata)

**Autor:** Claude, a petición de Ale · 2026-11-16 · rama `feature/exoticos-referencia-20261115`, base `integracion/rc-20261114`.

## Criterio de Ale
Los valores salen de libros escritos o supervisados por profesionales, así que **no se presentan como «sin validar»**. Cuando dos obras dan rangos distintos son criterios válidos de dos profesionales: **se muestran ambos con su cita; no se elige, promedia ni descarta ninguno.**

## Qué hay
- `lib/modules/exotics/domain/exotic_reference.dart`: modelo, citas y las 166 filas (todas las de la hoja «Exóticos complementos» de `vetdosis_reference_staging.raw_intake_rows`, lote 8). Seis especies: ratón, rata, hámster, jerbo, cuyo, chinchilla. Cuatro secciones: fisiología, reproducción y manejo, hematología, bioquímica.
- `lib/modules/exotics/presentation/exotics_menu.dart`: `ExoticsMenu`, consulta de solo lectura (especie → sección → parámetro). Cada parámetro lista una línea por obra: rango, nombre de la especie como lo da la obra (y su taxon si lo hay), obra, página y tabla.
- `test/exotics_reference_test.dart`: integridad (166 filas, citas), conservación de ambas obras y navegación.

## Fuentes
- De la Torre Suire, *Clínica de Mascotas No Convencionales: Mamíferos* (pp. 171, 175, 176, 190, 194, 205, 206).
- *Manejo y tratamiento de los animales exóticos* (fragmento escaneado; páginas 1, 2 y 4 del PDF).

## Un aviso que se conserva y una nota de nombres
1. **Fósforo y potasio del cuyo** (p. 176): la transcripción los marca «corroborar valor y unidad». No duda de la obra, sino de la transcripción; se contrasta con la página del libro.
2. **Nombres de hámster y jerbo:** cada obra usa su nombre (dorado, sirio, ruso, chino, grupo, sin especie; mongol, «del libro A», sin especie). Pueden ser nombres comunes de la región del autor y no una especie exacta, así que se muestran tal cual, sin homologar y sin tratarlos como error. El nombre científico solo aparece donde la transcripción de esa obra lo registra; no es una identificación nuestra.

Sinónimos de parámetro unificados para poder comparar (el nombre original se muestra): «Tamaño de camada» = crías por camada; «Glóbulos rojos» = eritrocitos; «Glóbulos blancos» = leucocitos totales. «Urea» y «BUN» **no** se unifican.

## Qué NO hace
- No guarda registros, no calcula dosis, no se liga a un paciente.
- No agrega datos fuera de la hoja. Aves, reptiles, anfibios y peces ornamentales aparecen solo como «En preparación».
- No toca `app.dart`, la navegación ni permisos. No escribe en Supabase.

## Montaje pendiente (requiere entorno Flutter)
1. En `lib/core/app.dart`, junto a `model.screen == 'Producción y grandes especies'`, añadir una rama para una pantalla «Exóticos» que devuelva `ExoticsMenu(allowed: …)`; `allowed` sale del mismo permiso que usa Producción para sus calculadoras.
2. Registrar «Exóticos» en el catálogo de módulos/navegación (revisar `module_access.dart`, `navigation_access.dart` y las pruebas que recorren el catálogo).
3. Correr `flutter analyze` y `flutter test`. **Esta rama no se compiló ni se probó: Claude no tuvo Flutter.** Ojo con el `assert` de `_parse` (11 campos por línea) y con `final exoticReferences = _parse()`.

## Fuera de alcance (sin definir con Ale)
- Dosis y fármacos para exóticos.
- Reptiles, anfibios, aves y peces ornamentales: no hay datos en Supabase; faltan los archivos.
