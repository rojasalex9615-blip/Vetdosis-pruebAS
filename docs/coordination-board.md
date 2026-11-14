# Tablón operativo compartido

Entrada única: [GitHub issue #31](https://github.com/rojasalex9615-blip/Vetdosis-pruebAS/issues/31).
Se reutilizó el tablón existente, conservando su historial. La división anterior
por tres frentes queda como historia, conforme a la indicación actual de Ale.

## Espejo en GitLab (2026-11-13)

El tablón de GitLab vive en
[issue #1](https://gitlab.com/rojasalex9615/vetdosispro/-/work_items/1) del repo
de código. Se abrió porque desde los contenedores de trabajo **no hay escritura
en GitHub** (sin `GITHUB_TOKEN`), mientras que en GitLab sí hay acceso real. No
sustituye al tablón de GitHub: es un espejo para no perder novedades. Si vuelve
el acceso a GitHub, la novedad se replica allí. Ninguno de los dos tablones
concede por sí solo autorización para fusionar, desplegar ni activar reglas
regulatorias.


El issue contiene tareas, autor/responsable, estado, rama, SHA/PR, bloqueos y
siguiente acción. Leerlo junto con sus comentarios antes de trabajar; volver a
leer antes de modificar contratos compartidos. Los participantes confirman su
propia aceptación. Publicar un encargo no demuestra lectura ni activa otra sesión.
El registro de Grok es un encargo comunicado por Ale; no se ha recibido aquí su
resultado ni un acuse directo. La regla de coordinación para futuros agentes se
incluye en AGENTS.md, candidata hasta integrarse esa rama.

El recap de 5.6 entregado por Ale está preservado en
`docs/regulatory/senasica/grupo-i/vetdosis_padron_grupo_I_preparacion.csv`, con hash
y atribución en `preparacion_provenance.json`. Mantiene las 471 filas originales,
identificadores únicos y todos los cruces pendientes. Sus fechas son atribuidas,
no verificadas de forma independiente. No cambia clasificaciones de la app.

CodeRabbit es el responsable de revisar e informar hallazgos según la indicación
de Ale. La asignación no acredita revisión ejecutada ni integración aprobada.

## Formato de novedades

- Autor/sesión y tarea aceptada.
- Estado: EN CURSO / ENTREGADO PARA REVISIÓN / BLOQUEADO / CERRADO.
- Repositorio, rama, base y SHA; archivos/contratos afectados.
- Entrega: PR/documento/artefacto y verificación realizada.
- Pendientes, bloqueo concreto, siguiente responsable y plazo solo si se acordó.

Un PR borrador con pruebas no equivale a revisión, integración, despliegue ni QA
con teléfonos. No publicar datos clínicos, secretos ni resultados de otro modelo
sin procedencia. No hay programación automática ni envío a Grok/5.6 por crear el
tablón. Los modelos con acceso al repositorio pueden consultarlo y actualizarlo;
el acceso de cada participante requiere verificación real.
