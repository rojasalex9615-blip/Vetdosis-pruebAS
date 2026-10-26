# Consolidación del 26 de octubre de 2026

Rama independiente `integration/consolidation-20261026`, basada en preview
`abd2f22cb0aa279f7ef0ce0f3a8ffea57ef72635`, incorpora Ajustes
`14380a3df9c4fedc9333d6c71e23d68ce34d5a4a` mediante merge conservador.
Original comparado: `b64ff80ca84bff29977f747c6052848da5103ad6`.

## Omisiones comprobadas y resueltas

- Recuperada del original la comparación entre claves de objetos Storage y
  metadatos del PostgreSQL restaurado en `restore_database_backup_isolated.py`.
  La preview ya llamaba este argumento, pero su implementación no lo aceptaba.
- Incorporadas correcciones recientes de Ajustes: iOS 15.5, JSON null,
  navegación del dashboard y pruebas de selección OCR.
- Evitado continuar la recarga de comisiones después de desmontar la pantalla.
- Publicación del artefacto debug depende de Flutter analyze, suite Flutter y
  pruebas locales de cifrado y transporte hospitalario.
- Manifest con SHA exacto, módulos, origen Sol y enlace a ejecución. Checksums
  relativos a la raíz del artefacto al extraerlo.

## Pendientes antes de una beta firmada

Esto NO certifica una reconciliación exhaustiva. Los workflows operativos de
respaldo/firma del original no se han copiado ni activado en este repositorio.
Existen diferencias funcionales en Auth, Hospital y Operations, y dos familias
SQL con prefijos coincidentes que necesitan revisión por contenido.

Faltan restauración real aislada PostgreSQL+Storage, pruebas RLS y recorrido con
dos clínicas, revisión de notificaciones/permisos y CI completo del commit final.
Las pruebas unitarias de restauración existentes no ejecutan Docker/PostgreSQL.
No se ha desplegado SQL ni funciones remotas. No fusionar main ni distribuir
esta preview como versión completa. Referencia: issue #40 del original.
