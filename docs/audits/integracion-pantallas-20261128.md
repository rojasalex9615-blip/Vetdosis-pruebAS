# Integración pendiente y revisión de pantallas

Ronda del 28 de noviembre de 2026, sobre la beta de profesores. La autorización de esta ronda incluye integrar los cambios pendientes y corregir fallos de pantallas. La revisión usa el armazón completo de VetDosisApp con repositorios sintéticos, fuentes reales y sombras activas. No acredita ejecución en un teléfono ni habilita permisos, pautas o funciones de servidor adicionales.

## Integración realizada y ramas revisadas

- PR 158 fusionado a beta en `990b6c2cd6c974b3723c6d3b46ae3323b59588da`: reúne #145 y #153–#157, Producción, calendario, jerarquía de Inicio e iconos.
- PR 159 fusionado después, en `f3e9b354d4e533fa88f5c4cb96537e73fc0772a1`: plan y matriz del piloto. Las filas manuales continúan pendientes.
- Esta rama incorpora las correcciones pendientes de #147 (fechas), #146 (filtro de responsable en agenda) y #143 (referencia inequívoca de peso vivo), preservando las mejoras posteriores de beta.
- Se incorporan las ramas documentales #130, #114 y #113. La extracción de fuentes #114 ya coincidía con el contenido de beta; el merge conserva su procedencia. El cambio #130 solo aclara comentarios del SQL 17A: no ejecuta esa migración ni valida dosis.
- Se traslada selectivamente el cambio #148: una presentación sin concentración puede consultarse; el cálculo sigue bloqueado sin concentración. Una concentración declarada debe usar la unidad admitida. No se une la historia antigua a beta.
- #121 corresponde a una escala tipográfica que ya tiene tema, guard y cambios posteriores en beta. Se conserva el diseño reciente y se corrige el tamaño condicional residual de 13 a 14; no se restauran capturas o geometrías antiguas.

Al comenzar había **95 PR abiertos**: 13 puntas ya contenidas en el conjunto, 7 pendientes de la misma historia y 75 de una historia distinta. Seis de los siete se incluyen por merge; el restante (#121) se trata como antecedente superado. De los 75 antiguos se porta #148; los otros 74 requieren comparar funcionalidad y procedencia, no constituyen una lista de 74 funciones ausentes. No se aplicó `--allow-unrelated-histories` ni se fusionó el main antiguo.

[Inventario de los 95 PR y tratamiento](estado-prs-20261128.csv). Las clasificaciones se refieren al corte inicial, no al contador actual de PR abiertos. Los PR apilados pueden conservar estado abierto aunque su código ya sea alcanzable desde beta.

Los bots no acreditaron revisión externa: CodeRabbit omitió la revisión por configuración de rama, Octopus informó falta de créditos y el bot de ChatGPT informó falta de clave. Se conserva esta distinción frente a los checks técnicos aprobados; no se atribuye aprobación a esos revisores.

## Fallos encontrados y correcciones

| Hallazgo reproducido | Causa | Corrección |
|---|---|---|
| Ficha de producto/lote recortada verticalmente en Inventario | La altura intrínseca de la fila con ListTile subestimaba el contenido real | La franja lateral se posiciona sobre una tarjeta de altura natural; no se reduce ni recorta el texto |
| Herramientas pecuarias desbordadas en 360 px y con letra ampliada | Rejilla con proporción fija y altura insuficiente | Tarjetas de altura natural, una/dos/tres columnas según espacio y escala de texto; rótulos completos |
| Estadísticas fallaba al dibujar lotes con texto ampliado | El valor lateral consumía todo el ancho de ListTile | Detalle debajo del título en pantallas estrechas y anchos flexibles en disposición amplia |
| El plan activo no se actualizaba al terminar su carga | Los valores se capturaban fuera del constructor que escucha al modelo | Se leen en cada notificación; una regresión comprueba la primera carga sin reconstruir el padre |
| Etiquetas del plan activo y tipo de espacio salían del ancho | Dos badges junto al título en una fila rígida | Badges separados bajo el nombre, con Wrap |
| Agenda repetía encabezado y usaba varias filas de pestañas | Título interior independiente de la cabecera y opciones en Wrap | AppPageHeading respeta la sección activa; pestañas en scroll horizontal; acciones del equipo separadas |
| Caja mostraba el título genérico de Inventario | La cabecera interior solo reconocía la ruta Inventario | También respeta la cabecera Caja, conservando el título al abrir la pantalla por separado |
| Fecha ISO de servidor y formateadores duplicados | Formato local a cada pantalla | Fecha de inventario y fechas de soporte/planes usan VetFormat |
| Vistas previas con fuente y sombras distintas | Arnés histórico cargaba Roboto/DejaVu y omitía activar difuminado de sombras | El arnés de Inicio usa Plus Jakarta Sans/VetIcons y sombras activas; los datos siguen siendo sintéticos |

## Cobertura visual de la ronda

Se recorren 29 destinos en dos configuraciones combinadas: **360 × 800 claro con escala 1.0** y **320 × 800 oscuro con escala 1.6**, 58 renderizados en total, sin excepciones de layout ni indicadores de carga pendientes al finalizar el recorrido. No representa todas las combinaciones de modelos de teléfono, tamaño y tema.

- Inicio, Agenda, Pacientes, Hospitalización, Receta y Formatos.
- Inventario, Caja, Cálculos, Cálculo rápido, Vademécum, Operaciones de dosis y Cálculos clínicos.
- Producción y grandes especies, Dashboard Pecuario, Exóticos y Dashboard Exóticos.
- Servicios, Proveedores, Productividad y semana, Pendientes del equipo y Control de asistencia.
- Estadísticas, Ajustes, Respaldo, Planes, Ayuda y soporte, Información de la app y Asistente IA.

Se verifican carga, layout y navegación entre destinos con fixtures. Los espacios sin repositorio de producción muestran su estado vacío real. No se prueba cada formulario, teclado abierto, cámara, impresora, notificación nativa, acción profesional ni integración externa por navegar a su pantalla. Los errores de fixtures incompletos se corrigieron en el arnés, sin atribuirlos a la app.

Las regresiones permanentes cubren fichas de lotes y herramientas a 320 px con fuentes reales y escalas 1.0/1.6, estadísticas con detalle largo y badges de planes ampliados. Las pruebas de las ramas incorporadas mantienen el rechazo de pautas ambiguas y el bloqueo de cálculo sin concentración.

## Siguiente comprobación de uso

La matriz del piloto conserva sus 45 casos pendientes. La siguiente ronda manual debe instalar el APK del commit integrado y cubrir guardado/reapertura/segundo dispositivo, teclado/cámara/PDF y permisos con sesiones reales. Cambiar el código de beta no actualiza un APK ya instalado ni implica aprobar esa lista.
