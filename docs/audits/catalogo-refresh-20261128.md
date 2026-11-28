# Catálogo, Ramsey y actualización de pantallas · 28 noviembre 2026

## Procedencia e integración selectiva

La beta contenía un catálogo legado `catalog.v1.json` sin fichas. Eso no significaba que faltaran las tablas: las vistas públicas de Pruebas contienen 540 principios activos y 1,077 pautas. Se localizaron en `feat/vademecum-farmacologico-20261126` (punta 27bbcb2), una rama sin PR, los cambios que no habían llegado a beta:

- 7d86744: carga de Ramsey y resolución de nombres.
- 38fc2e9: Ramsey dentro de la tabla multiespecie.
- 33f5dff: bibliografía y campos de cálculo por pauta.

Se recuperan selectivamente el catálogo y sus vistas/cálculos. La rama completa contiene otros cambios de autenticación, equipo y expedientes; no se fusiona en bloque. El inventario anterior de 95 PR no equivalía a revisar todas las ramas sin PR. El remoto local contiene 167 referencias al realizar esta revisión.

El asset recuperado coincide con la versión remota v1, actualizada el 26 de noviembre a las 11:32:15 UTC: 540 principios, 1,077 pautas y 586 con campos numéricos convertibles. De ellas, 1,023 conservan autor «Ramsey, I. (ed.) / BSAVA» y título «Vademécum farmacológico para perros y gatos». No se duplica su importación ni se cambian las dosis. Son pautas bibliográficas; la existencia de números convertibles no acredita validación clínica.

Se verificó igualdad del contenido relevante mediante agregados MD5, usados únicamente como comparación de datos: principios `d85a0c5fe30fa83200ab96e1e046df83` y pautas con dosis literal/bibliografía `ddb2cab5a6207110f90dda54392e98a2`. No se ejecutó escritura ni migración en Supabase.

## Comportamiento resultante

El menú de Cálculos ofrece «Dosis por principio activo» y «Dosis por marca comercial». El primer acceso carga el catálogo bibliográfico cuando el legado está vacío; las fichas verificadas o personales existentes conservan su flujo. Vademécum y Biblioteca también presentan la colección por principio y sus citas. Esta versión usa una copia incluida en el APK: no sincroniza cambios futuros de las tablas automáticamente.

La calculadora exige especie y elección explícita de pauta; preserva rangos y separa autores. Las unidades sin conversión admitida quedan para consulta. Las pautas en mL/kg producen mL directamente, sin tratarlas como mg ni volver a convertirlas por concentración. El acceso por escáner ofrece el catálogo cuando falta una ficha verificada; OCR no decide la dosis.

No se activa el almacén local automático ni el guardado clínico remoto de la rama donante. Los cálculos bibliográficos son de sesión salvo inyección explícita de un destino; el flujo normal no ofrece una promesa de guardado compartido que aún no se haya implementado para este cálculo.

## Recargas y botón flotante

La comprobación periódica devolvía una instancia nueva de permisos equivalentes. Su identidad se usaba en la clave de Inicio/Estadísticas y reconstruía el estado. Se comparan ahora sus capacidades por valor y con mapas inmutables. Una revocación o cambio real de identidad/rol conserva su efecto; una comprobación sin cambios conserva búsqueda y estado.

El botón flotante abre el escáner sobre la pantalla actual, de modo que volver conserva el borrador. Se verifica también la ventana de cambios sin guardar: continuar mantiene el texto y descartar vuelve sin escribir.

## Validación y límites

Las pruebas dirigidas cubren conteos, Ramsey, citas, rangos exactos, exclusión de unidades, búsqueda, menús, escáner, refresco y revocación. Se renderizan además calculadora e índice con las fuentes e iconos reales en 360 px claro y 320 px oscuro con escala 1.6, sin excepciones de layout. Las etiquetas de clasificación pasan bajo el nombre en espacio estrecho para no comprimirlo. La regresión adicional comprueba carga real desde el acceso legado vacío, separación mL/mg y ambas acciones de la ventana emergente a 320 px con texto ampliado. La revisión visual previa y la matriz del piloto se describen en `integracion-pantallas-20261128.md`; los 45 casos manuales siguen pendientes de teléfono/cuentas reales. No se afirma cobertura exhaustiva de todos los botones ni aprobación clínica del catálogo.
