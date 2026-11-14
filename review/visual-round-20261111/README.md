# Ronda visual Neu · 11 nov 2026

Base: `integracion/apk-completo-20261111` (3d21e08), que es de donde sale el APK
que Ale tiene en el teléfono. Encargo de Ale con capturas del estado actual,
de las versiones anteriores que daba por buenas y de las maquetas objetivo.

Solo cambia el estilo Neu. El Clásico, los cálculos, permisos, textos clínicos
y la estructura de las calculadoras no se tocan.

- **Glow**: fuera de la tarjeta entera; queda solo en la franja de cabecera y
  muy tenue (0.55). La franja usa el tono de la sección apagado, como en las
  cabeceras anteriores. Vale para Inicio y para las calculadoras, que conservan
  sus divisiones y su contenido.
- **Cabecera de pantalla**: banda aqua → lila en la barra y hoja de contenido
  con esquinas redondeadas encima. El cajón abre con la misma banda.
- **Botón principal**: recorrido aqua → violeta de «Ingresar» / «Calcular».
  Blanco sobre el recorrido: 4.0:1 en el extremo aqua, 4.6:1 en el violeta.
- **Inicio**: módulos con placa en relieve y línea de apoyo (dato consultado o
  pista, nunca una cifra inventada), barras del gráfico con degradado y citas
  como renglones con barra de color y etiqueta de hora.
- **Barra inferior**: la pestaña activa es una placa clara redondeada.
- **Acceso y bienvenida**: velo de marca al fondo, título centrado, campos con
  icono y Google en placa oscura.
- **Pasos numerados** (Formatos y los demás que usan `VetSectionHeader` con
  `step`): pasan a tarjeta con el cuadro y el título arriba.

Segunda tanda, mismo día:

- **Tarjetas de Material** (`Card`, unas setenta llamadas): en Neu eran del
  color exacto del lienzo y sin sombra. Pasan a placa levantada, un punto más
  clara y con sombra suave.
- **Hospitalización**: cada paciente internado abre con franja de cabecera
  (jaula y nombre) como el resto de apartados. El contenido es el mismo.
- **Vademécum**: el filtro de fichas pasa de lista desplegable a pastillas, y
  cada ficha lleva barra de color según su origen (app, clínica o personal).
  Capturas: [Hospitalización](hospitalizacion-claro.png) ·
  [Vademécum](vademecum-claro.png) (sin fichas en el arnés).

Tercera tanda, con las maquetas de Caja, Perfil y calendario:

- **Caja**: resumen del día y métodos de pago como mosaicos, «Nueva venta» en
  el botón redondo y el resto como acciones secundarias. Los importes son los
  de `day_totals` con su nombre real (ventas netas, gastos en efectivo,
  resultado capturado); la maqueta decía «ingresos / egresos / saldo», que el
  servidor no entrega con ese significado. El desglose completo queda plegado.
- **Venta**: total en tarjeta, método de pago en tres mosaicos en vez de lista
  desplegable, y teclado numérico para el efectivo recibido con el cambio. Es
  ayuda de mostrador: no se guarda ni viaja al servidor (hay prueba).
- **Escáneres**: una pantalla con los dos lectores, código de barras y
  etiqueta para dosis, cada uno en su tarjeta.
- **Perfil**: «Mi cuenta» abre con banda de marca, foto o icono grande, el
  espacio activo y el rol.
- **Calendario**: el día elegido es una pastilla de color y hoy lleva trazo.
  Capturas: [Caja](caja-claro.png) · [Escáneres](escaneres-claro.png) ·
  [Perfil](perfil-claro.png) · [Calendario](calendario-claro.png).

Capturas con cuenta y datos ficticios: [Inicio](inicio-claro.png) ·
[Inicio oscuro](inicio-oscuro.png) · [Cálculos clínicos](calculos-clinicos-claro.png) ·
[Formatos](formatos-claro.png) · [Secciones](secciones-claro.png) ·
[Menú](menu-claro.png) · [Acceso](acceso-claro.png) · [Bienvenida](bienvenida-claro.png).
El logotipo y la animación de bienvenida no cargan en el arnés de pruebas; en
el teléfono sí.

Reproducir:
`flutter test test/previews/capture_visual_round.dart --dart-define=VISUAL_ROUND_DIR=review/visual-round-20261111`

Validación: `flutter analyze` limpio y 818 pruebas pasan, 1 omitida (Flutter
3.47.6). Implementado; **no** revisado por CodeRabbit, **no** integrado, **no**
desplegado y **no** probado en teléfono.

Pendiente respecto a las maquetas, porque es contenido y no solo estilo:

- Laboratorio no existe en esta rama (vive en `feature/laboratorio-20261110`).
- Perfil: teléfono, correo, cédula y horario de la maqueta no se pintan
  porque la pantalla de cuenta no recibe esos datos.
- Gráficas de dona y objetivos de «Resumen»: no hay metas en el servidor.
- Pago por QR: no existe ese cobro en la app.
- Constantes (FC, FR, temperatura) y barra de avance del tratamiento en la
  tarjeta de Hospitalización: la hoja no trae esos datos resumidos.
- Categorías terapéuticas del Vademécum (antibióticos, analgésicos…): las
  fichas no llevan categoría; las pastillas filtran por origen.

Tablón: el issue #31 vive en otro repositorio, fuera del alcance de la sesión
que hizo este trabajo. Esta nota queda como registro local; nadie fue
notificado allí.
