# Analíticas de laboratorio: diseño (8 nov 2026)

Estado: cálculo y pruebas listos (`lib/modules/laboratory/domain/lab_result.dart`). Faltan base de datos y pantalla, que van con Opus.

## Reglas ya fijadas en el cálculo
- Un rango de referencia exige fuente; sin fuente no existe.
- Sin rango para la especie: el resultado se guarda y se muestra, sin juicio.
- Unidad distinta a la del rango: no se convierte ni se juzga.
- Dos fuentes para el mismo analito y unidad: se usa el rango más amplio y se muestran ambas fuentes.
- La toma de muestra no admite analitos repetidos.

## Lo que debe cubrir la parte de Opus (SQL)
Seguir el modelo de hospitalización (`14F_hospital_care_results.sql`): tablas en `private`, acceso por permisos efectivos, autoría, y correcciones que conserven el original (nada se edita ni se borra).
- Toma de muestra: paciente, clínica, fecha de toma, origen (laboratorio externo, equipo propio), autor.
- Resultado: analito, valor como texto decimal, unidad, y la toma a la que pertenece.
- Rangos de referencia: universales, con especie, unidad, límites y fuente obligatoria; `verificado` en falso por defecto.
- Sin precarga de rangos: los datos clínicos entran por el modo revisión, como el resto del catálogo.

## Pendiente de decisión (de Ale y un MVZ)
- Lista inicial de analitos por especie y de dónde saldrán los rangos (por ejemplo, una fuente por especie con cita).
- Si los resultados externos se capturan a mano o se adjuntan como PDF o foto privada (como las pruebas rápidas).
