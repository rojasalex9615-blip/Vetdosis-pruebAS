# Exóticos · referencias de mamíferos pequeños (candidata)

**Autor:** Claude, a petición de Ale · 2026-11-15 · rama `feature/exoticos-referencia-20261115`, base `integracion/rc-20261114`.

## Qué hay
- `lib/modules/exotics/domain/exotic_reference.dart`: datos y modelo. 6 grupos de especie (ratón, rata, hámster, jerbo, cuyo, chinchilla) y 3 secciones (reproducción, hematología del cuyo, bioquímica del cuyo).
- `lib/modules/exotics/presentation/exotics_menu.dart`: `ExoticsMenu`, consulta de solo lectura (especie → sección → datos).
- `test/exotics_reference_test.dart`: integridad de datos y navegación.

## De dónde sale
Lote 2 de exóticos (Drive de Ale, `VetDosis_lote2_exoticos.csv`), transcrito de «Clínica de Mascotas No Convencionales: Mamíferos» (M. Á. de la Torre Suire), pp. 171, 175 y 176. **Todo queda «pendiente de revisión clínica».** La propia transcripción marca fósforo y potasio del cuyo para corroborar valor y unidad; la pantalla lo muestra.

## Qué NO hace
- No guarda registros, no calcula dosis, no se liga a un paciente.
- No agrega datos fuera del CSV. Aves, reptiles, anfibios y peces ornamentales aparecen solo como «En preparación».
- No toca `app.dart`, la navegación ni permisos.

## Montaje pendiente (requiere entorno Flutter)
1. En `lib/core/app.dart`, junto a `model.screen == 'Producción y grandes especies'`, añadir una rama para una pantalla «Exóticos» que devuelva `ExoticsMenu(allowed: …)`; `allowed` sale del mismo permiso que usa Producción para sus calculadoras.
2. Registrar «Exóticos» en el catálogo de módulos/navegación (revisar `module_access.dart`, `navigation_access.dart` y las pruebas que recorren el catálogo).
3. Correr `flutter analyze` y `flutter test`. **Esta rama no se compiló ni se probó: Claude no tuvo Flutter.**

## Fuera de alcance (sin definir con Ale)
- Dosis y fármacos para exóticos.
- Hematología/bioquímica de otras especies; el CSV solo trae las del cuyo.
