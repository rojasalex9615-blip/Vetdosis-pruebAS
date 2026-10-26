# Respaldo del servidor de pruebas — 25 de octubre de 2026

La base PostgreSQL de Supabase Pruebas se exportó y cifró en la ejecución
[40178192626](https://github.com/rojasalex9615-blip/Vet-dosis-pruebas/actions/runs/40178192626).
El archivo se descifró y restauró en una base aislada sin red en la ejecución
[40178339771](https://github.com/rojasalex9615-blip/Vet-dosis-pruebas/actions/runs/40178339771).
La verificación de tablas y conteos pasó. No se modificó la base activa.

El flujo `backup-test-database.yml` permite crear una copia cifrada manualmente
y conserva el artefacto siete días en GitHub Actions. Depende de que
Actions, los secretos del repositorio y Supabase estén disponibles. El ensayo
de migraciones sobre una copia ya actualizada es opcional y separado de la
verificación de restauración.

El flujo `backup-test-storage.yml` creó una copia cifrada de **1 objeto de
38 832 bytes** en la ejecución
[40179599273](https://github.com/rojasalex9615-blip/Vet-dosis-pruebas/actions/runs/40179599273).
La [recuperación aislada del artefacto](https://github.com/rojasalex9615-blip/Vet-dosis-pruebas/actions/runs/40179755486)
comprobó el hash cifrado, manifiesto y SHA-256 del binario, sin conectarse al
proyecto activo. El flujo individual queda disponible manualmente, también con
retención de siete días. Usa una clave de servicio obtenida solo durante la
ejecución con el token administrativo; no la publica ni la guarda como archivo.

**Alcance:** la copia de PostgreSQL contiene base y metadatos de Storage; la
segunda contiene los binarios. Son dos capturas separadas, sin snapshot atómico
común. Aún faltan restaurar el servicio Storage y los secretos/configuración
de plataforma e identidades globales de roles y una copia fuera de GitHub.
No se afirma recuperación completa del servicio.

El [ensayo conjunto 40221915966](https://github.com/rojasalex9615-blip/Vet-dosis-pruebas/actions/runs/40221915966)
pasó con la copia PostgreSQL 40178192626 y la copia Storage 40179599273.
Se verificaron los dos archivos cifrados y la correspondencia de objetos
recuperados con los metadatos de la base restaurada en un contenedor sin red.
El informe `joint-backup-evidence` está adjunto a la ejecución. Las capturas
están separadas por unos 21 minutos y no constituyen una instantánea atómica.

El flujo `restore-test-backup-pair-isolated.yml` permite comprobar ambos
artefactos juntos. Descifra y verifica cada archivo, restaura PostgreSQL en un
contenedor sin red y compara los nombres y buckets de todos los binarios
recuperados con `storage.objects` de esa base. Acepta únicamente artefactos del
proyecto de pruebas separados por menos de 24 horas; una diferencia de objetos
falla el ensayo. El informe publica solo cantidades y el resultado, nunca
nombres de objetos ni contenido. La prueba no levanta un servicio Storage ni
restaura Auth, secretos o roles globales; por ello no acredita todavía la
recuperación completa del servicio.

## Pareja programada y verificada

El flujo `backup-test-pair-verified.yml` ejecuta una captura nueva de PostgreSQL
y Storage a las 09:17 UTC. Restaura PostgreSQL en un contenedor sin red y compara
los archivos recuperados con `storage.objects` antes de publicar el artefacto
`vetdosis-verified-backup-pair`. Si falla cualquiera de las dos capturas o la
comparación, el flujo no publica una pareja aparentemente válida. Conserva los
dos archivos cifrados, ambos manifiestos y el informe durante 30 días en GitHub
Actions. Los secretos solo se entregan a los pasos que los necesitan.

Esta ejecución sigue siendo una captura secuencial: si cambian los archivos
entre las dos exportaciones, la comparación puede fallar y habrá que repetirla.
La [primera ejecución 40242573710](https://github.com/rojasalex9615-blip/Vet-dosis-pruebas/actions/runs/40242573710)
pasó la verificación conjunta y publicó el artefacto cifrado. Las dos
programaciones individuales se retiraron; sus flujos conservan ejecución
manual. Esta automatización no sustituye una copia fuera de GitHub ni
reconstruye Auth, secretos de plataforma, Storage como servicio o roles globales.
