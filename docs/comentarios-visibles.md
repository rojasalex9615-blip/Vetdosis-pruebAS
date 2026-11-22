# Comentarios visibles dentro de la app

Qué es: textos que el usuario lee en pantalla, no los comentarios `//` del
código. Se buscaron notas dirigidas al equipo, al docente o a los apuntes de
clase, del tipo «revisa tus apuntes» o «consulta con tu profesor».

Alcance: `lib/` y los JSON de `assets/` que la app muestra. El registro de
comentarios del código está en `docs/comentarios-colaboradores.md`.

Criterio: se separan tres clases.

1. **Instrucción interna**: una tarea o un pendiente para el equipo. No debe
   leerse en la app.
2. **Aviso clínico**: advierte que el dato no está verificado. Se conserva,
   porque protege al usuario.
3. **Procedencia**: dice de dónde salió el dato (clase, tabla, manual). Se
   conserva mientras el dato siga sin verificar.

## Cambios aplicados

| Apartado | Antes | Ahora |
|---|---|---|
| Producción → Avicultura → Equipos | «Las etapas de estos apuntes son distintas de las bandas por semanas; se conservan tal como llegaron.» | «Las etapas de esta referencia son distintas de las bandas por semanas.» |
| Producción → Avicultura → cálculo | «Fase 2 pendiente: redistribución, vínculo con medicación en agua/alimento y retiro del huevo. Estos cálculos no crean tratamientos.» | «Estos cálculos no crean tratamientos ni registros de granja.» |
| Producción → Alimentación | «Las tablas por talla y temperatura de los apuntes aportados están pendientes de verificación…» | «Las tablas por talla y temperatura de la referencia están pendientes de verificación…» |
| Producción → Porcinos → Semen | «Dilución y área de conteo por confirmar con el material del curso.» | «Dilución y área de conteo pendientes de verificación.» |
| Avicultura → Datos pendientes e incubación | `fuente`: «Clase Prod. Avicola 15-sep-2026 (corregido por el profesor en clase)» | `fuente`: «Clase Prod. Avicola 15-sep-2026» |

La hoja de ruta que se quitó de Avicultura (redistribución, vínculo con
medicación en agua/alimento y retiro del huevo) queda registrada aquí como
trabajo futuro, no como texto de pantalla.

## Se conservan

| Apartado | Texto | Clase | Motivo |
|---|---|---|---|
| Avicultura → Gallinas | «Referencias v1 sin verificar. Estimación geométrica; no certifica bienestar, ventilación ni capacidad operativa.» | Aviso | Evita que se tome como dato validado. |
| Avicultura → Postura | «Postura · referencias de clase sin verificar (CUCBA).» | Procedencia + aviso | Dice de dónde salió y que no está validado. |
| Avicultura → Engorda | «Pollo de engorda · referencias de clase sin verificar.» | Procedencia + aviso | Igual que el anterior. |
| Avicultura → Índices productivos | «Índices productivos · fórmulas de clase sin verificar.» | Procedencia + aviso | Igual que el anterior. |
| Producción → menú | «Las referencias de engorda son de clase (CUCBA; tabla Cobb) y están sin verificar.» | Procedencia + aviso | Igual que el anterior. |
| Producción → Porcinos | «Cálculos de sesión con valores de referencia de clase. No guardan registros de granja y no son metas de rendimiento.» | Aviso | Delimita el alcance del cálculo. |
| Producción → Porcinos → escenarios | «Valores de referencia de la clase (Pork School, ago-2026), no metas…» | Procedencia + aviso | Igual que el anterior. |

## Notas internas que no se muestran

Estas viven en `assets/clinical/aviculture/pendientes_avicola.v1.json` y la app
no las pinta: `alcance` de la revisión externa y los `accion` con «pendiente:
confirmar con el docente», «revisar con proveedor» o «corregir el CSV antes de
subir a Supabase». Se dejan en el activo como rastro de la revisión.

## Cómo se buscó

Se revisaron las cadenas visibles de `lib/` (`Text`, `VetNotice`, mensajes) y
los campos de los JSON que la app muestra (`fuente`, `estado`, `parametros`,
`incubacion`). No se encontró la frase literal «revisa tus apuntes» ni
«consulta con tu profesor»; los equivalentes reales son los de las tablas de
arriba.
