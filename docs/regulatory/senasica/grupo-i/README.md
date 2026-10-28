# Padrón Grupo I: evidencia recibida, pendiente de contraste

El usuario proporcionó el CSV y después identificó su procedencia mediante el
endpoint gubernamental ATDT/SENASICA. También aportó los enlaces a dos acuerdos
alojados en gob.mx. Las tres descargas devolvieron HTTP 403 desde este entorno.
Por tanto se conserva la atribución del usuario, sin afirmar que los bytes
adjuntos coinciden con la versión remota actual o que se revisaron los PDF.
Las URLs completas y SHA-256 se encuentran en `provenance.json`.

## Contenido comprobado del adjunto

- 471 filas, todas con grupo I, y 471 números de registro distintos.
- Cuatro columnas completas: razón social, nombre de producto, registro y grupo.
- 121 textos distintos de razón social; no equivale a 121 empresas conciliadas.
- Sin fecha de actualización, ingredientes, concentraciones, dosis o especies.
- Se preserva el nombre «17 ?Eta»; no se corrige sin verificar el original.

El CSV original se conserva sin transformación. El nombre del endpoint contiene
«vigentes», pero no aporta por sí solo una fecha de publicación ni acredita la
vigencia actual de cada fila del adjunto.

## Cruce preliminar con el catálogo comercial

`cruce_nombres_pendiente.csv` compara únicamente nombres normalizados contra las
662 filas del catálogo de fabricante: 28 entradas tienen un candidato único,
2 tienen varios candidatos y 441 no tienen coincidencia exacta de nombre.
Estas últimas pueden corresponder a productos adicionales o variantes de nombre;
no prueban ausencia del catálogo ni clasificación distinta.

No se ha validado la identidad por registro, laboratorio, formulación y
presentación. Ninguna coincidencia por nombre constituye una clasificación
publicada. No se sustituyen ni amplían los assets regulatorios de ejecución.
No se cambia dispensación, recetas, permisos, devoluciones ni cálculo de dosis.

## Siguiente validación

1. Conseguir las copias accesibles de los dos acuerdos y contrastar texto,
   modificaciones, fechas y disposiciones aplicables. Estos enlaces no demuestran
   por sí solos que no existan modificaciones posteriores.
2. Contrastar el adjunto con una descarga oficial accesible y documentar su fecha.
3. Conciliar las identidades comerciales por registro y presentación; los nombres
   solo proponen candidatos para revisión.
4. Versionar la clasificación y las reglas respaldadas por referencias concretas
   antes de activar restricciones o formatos en la aplicación.

La ausencia en un padrón de Grupo I no determina Grupo II, Grupo III ni ausencia
de restricciones. El padrón tampoco sustituye las fichas de dosis del fabricante.
