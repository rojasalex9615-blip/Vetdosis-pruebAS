# Informe de cruce — Padrón SENASICA Grupo I × Vademécum comercial VetDosis Pro

**Fecha:** 2026-10-26  
**Responsable:** Grok (xAI)  
**Fuentes:**
- Padrón: `vetdosis_padron_grupo_I_preparacion.csv` (471 registros, datos SENASICA actualizados 2025-08-22)
- Vademécum comercial: `VetDosis_verificado_completo.csv` (662 productos verificados)
- Grupos de verificación en Drive (`VERIFICACION_GRUPO_*.md`)

## Limitación estructural importante

El vademécum comercial actual **no contiene número de registro sanitario**.  
Por tanto **no es posible** declarar coincidencias **Exactas** por registro (criterio prioritario del encargo).  
Todas las coincidencias encontradas son por **nombre comercial normalizado + fabricante** → clasificadas como **PROBABLE** (o CONFLICTO cuando hay ambigüedad).

## Resultados cuantitativos

| Estado de cruce     | Cantidad | % del padrón |
|---------------------|----------|--------------|
| Exacta (por registro) | **0**  | 0 % |
| Probable              | **30** | 6.4 % |
| Conflicto             | **3**  | 0.6 % |
| Sin coincidencia      | **438**| 93.0 % |
| **Total padrón**      | **471**| 100 % |

- Productos del vademécum comercial involucrados en algún match: **28**
- Productos del Grupo I aún no presentes en el vademécum: **438**

## Archivos generados (en carpeta Drive del proyecto)

| Archivo | Contenido |
|---------|-----------|
| `vetdosis_cruce_senasica_grupo_I.csv` | Los 471 registros oficiales + estado de cruce, evidencia, producto comercial relacionado y observaciones |
| `vetdosis_productos_grupo_I_faltantes.csv` | 438 productos del padrón sin correspondencia en el vademécum |
| `vetdosis_conflictos_regulatorios.csv` | 3 registros con múltiples candidatos fuertes (familia Trioxil / Alpha Chem) |

## Observaciones sobre conflictos

Los 3 conflictos corresponden a la familia **Trioxil** (Alpha Chem): el padrón distingue presentaciones (Trioxil, Trioxil 500, Trioxil 800) y el vademécum tiene entradas que generan match múltiple sobre el mismo nombre base. Requieren revisión manual de presentación/concentración (sin inventar datos).

## Criterios aplicados

1. Prioridad teórica: número de registro → **no aplicable** (ausente en vademécum).
2. Secundario: nombre comercial normalizado (sin acentos, puntuación unificada) + similitud de razón social.
3. Se conservaron siempre los valores originales del padrón y del vademécum.
4. No se inventaron registros, concentraciones, especies ni clasificaciones.
5. No se modificaron tablas Supabase ni se ejecutaron migraciones.

## Fundamentos normativos (consulta de referencia)

- Acuerdo de clasificación y prescripción de productos farmacéuticos veterinarios (12 de julio de 2004).
- Modificación del 5 de marzo de 2012.

**Nota:** No se asume que productos con el mismo principio activo pertenezcan automáticamente al mismo grupo. La clasificación oficial del padrón SENASICA (columna `grupo_original = I`) se respeta como dato de origen. Antes de declarar vigencia operativa de una clasificación en la app, el equipo debe comprobar si existen disposiciones posteriores a 2012 aplicables al producto concreto.

## Próximos pasos recomendados (para el equipo)

1. Enriquecer el vademécum comercial con **número de registro sanitario** (cuando exista en fichas PLM o catálogos de fabricante) para poder subir coincidencias de PROBABLE → Exacta.
2. Revisar manualmente los 30 PROBABLE y los 3 CONFLICTO.
3. Decidir priorización de los 438 faltantes de Grupo I (muchos son hormonales, anestésicos, progestágenos, etc.).
4. Solo después de revisión humana: plantear importación controlada (rama independiente, dry-run, reversión).

## Restricciones respetadas

- Sin inventar datos.
- Sin confundir clasificación regulatoria con dosis clínicas.
- Sin modificar tablas activas ni ejecutar migraciones.
- Sin fusionar ramas ni desplegar.
- Trabajo documentado; listo para revisión del equipo / issue #31.

---
*Fin del informe de diagnóstico y cruce.*
