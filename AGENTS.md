# Coordinación de VetDosis

El tablón compartido es el [issue #31](https://github.com/rojasalex9615-blip/Vetdosis-pruebAS/issues/31). Espejo en GitLab: [issue #1](https://gitlab.com/rojasalex9615/vetdosispro/-/work_items/1), para cuando no haya escritura en GitHub.

- Antes de iniciar trabajo, leer su estado y novedades recientes. Confirmar repositorio, rama y SHA: `Vetdosis-pruebAS` y `Vet-dosis-pruebas` son repositorios distintos.
- Registrar la tarea y la sesión que la acepta, su alcance, rama/base y archivos o contratos afectados. Comprobar posibles solapamientos antes de editar.
- CodeRabbit es responsable de las revisiones y de informar hallazgos, por indicación de Ale. Registrar el acuse y resultado reales; no dar una revisión por hecha por asignarla.
- Al entregar, actualizar con PR, SHA, pruebas realizadas, límites y siguiente acción. Distinguir implementado, revisado, integrado, desplegado y probado en teléfono.
- No atribuir aceptación o avances a otros modelos sin evidencia. Un encargo de Ale puede registrarse como tal, con acuse pendiente.
- Conservar historial y usar el tablón existente; evitar tableros paralelos. No publicar secretos ni datos clínicos/personales.
- Si GitHub no está disponible, dejar una nota local con los cambios que falte publicar y comunicar el bloqueo; no afirmar que se notificó a otros. El tablón de GitLab es el espejo para no perder novedades; no sustituye al de GitHub.
- En el código, el token de GitLab disponible llega por `git credential` (funciona en `git` y con la cabecera `Authorization: Bearer`); el de la variable `GITLAB_TOKEN` da 401. Para la API usar el del helper.

Las instrucciones actuales de Ale tienen prioridad sobre repartos históricos. El tablón no concede por sí solo autorización para fusionar, desplegar o activar reglas regulatorias.

## Notas técnicas

- Los `*Boundary` que envuelven el armazón (`ModuleAccessBoundary`, `ClinicExperienceBoundary`, `BetaBoundary`) **no** deben cambiar la forma de la raíz del árbol al alternar entre aviso y contenido: si el contenido pasa de raíz a `Expanded` (o al revés) se reparenta el subárbol y un elemento que aún depende de un `InheritedWidget` revienta con la aserción de `InheritedElement.notifyDependent` (`framework.dart:6430`), además de duplicar la pantalla. El contenido conserva puesto y clave; el aviso se añade o quita como hermano.
- La ayuda de uso de la app que usa IA (`StarterHelpPanel`) vive en «Ayuda y soporte», no en el Asistente: es un producto distinto del chat con clave propia y no debe compartir su historial.
- Para correr la suite hace falta el SDK de Flutter. El entorno real usa **Flutter 3.50.0** (Dart 3.14.0): `cupertino_icons ^2.0.0` exige Dart ≥3.12, así que Flutter 3.38.x no resuelve. En los contenedores de trabajo se instala en una ruta temporal (por ejemplo `/tmp/f/flutter`) y no se conserva entre sesiones. Con 3.50.0 `flutter analyze` reporta ~248 avisos `deprecated_member_use` de `package:flutter/material.dart` (sugiere `material_ui`), preexistentes en todo el repo.
