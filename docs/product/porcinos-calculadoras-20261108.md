# Porcinos: cuatro calculadoras sin base de datos (8 nov 2026)

Rama `feature/porcino-calculadoras-20261108` desde `main` (769b831). Sin SQL ni registros.

| Módulo | Actividad | Fuente (Drive `Coordinacion_Agentes_VetDosis`) |
|---|---|---|
| Ventilación de la sala | Gestación, maternidad y destete, engorda | VetDosis_Referencia_Porcino (VentWorkshop, Carlos Anadón) |
| Capacidad inversa (cerdos/semana o m² → vientres) | Reproducción y gestación | VetDosis_Remodelaciones_Redimensionamiento |
| Revisión de bioseguridad + escala de distancias | Bioseguridad y ambiente (actividad nueva) | VetDosis_Bioseguridad |
| Nitrógeno, huella hídrica gris y NCA | Bioseguridad y ambiente | VetDosis_Dictamen_Ambiental_Yucatan_SEMARNAT |

## Decisiones y límites
- Ventilación: las tablas en CFM y en m³/h del material no coinciden en engorda ni en destete cálido. Se ofrecen ambas, sin mezclarlas. Los «>» se muestran como mínimo («≥»).
- Capacidad inversa: se redondea hacia arriba con el factor exacto (destetados ÷ 52). La hoja de clase da 769 con factor 35; aquí 770.
- NCA: el CSV define NCA = HHGris ÷ Runitaria_Municipal, pero la recarga unitaria está en m³/km². Se implementó recarga disponible = recarga unitaria × superficie. Pendiente que Grok confirme en la p. 84 del dictamen.
- Constantes de Yucatán precargadas y editables (18 kg N, Cnat 1.5, Cmax 3.0 o 10.0, recarga 175 336).
- La lista de bioseguridad no se guarda; la «Filtración de aire (?)» conserva la duda del original.
- No se probó con Flutter (no hay SDK en el entorno): sintaxis validada con parser, los números de los tests verificados a mano.
