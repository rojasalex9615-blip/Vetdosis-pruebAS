# Acceso y bienvenida · 23 nov 2026

Encargo de Ale sobre el APK del teléfono, con capturas del estado actual y de la
versión anterior que daba por buena: botones demasiado altos, iconos que no se
distinguen entre sí y logotipo pequeño en el inicio de sesión.

## Botones: 48 → 40 de alto

Las dos capturas del acceso se compararon píxel a píxel. Son idénticas salvo en
una cosa: el botón «Ingresar» mide **96 px** en la captura de las 02:37 y
**80 px** en la de las 00:41. A densidad 2.0 del teléfono, **48 dp contra 40**.
Los campos de texto no cambiaron: las dos cajas están en las mismas filas
(y 777..790 y y 905..918) en ambas capturas.

El alto salió del commit `17537e8`, «Registro con como nos encontro, planes sin
duplicado y botones parejos», que dice en su descripción: «Iniciar sesion, Crear
cuenta y Continuar con Google con alto 48».

Se quita el `minimumSize` de los cuatro botones y vuelven a los **40 de Material
3**, que es lo que muestra la captura buena:

- `auth_screen`: «Ingresar / Crear cuenta» y «Continuar con Google».
- `public_welcome_screen`: «Iniciar sesión» y «Crear cuenta».

No se pierde accesibilidad: los botones de Material usan
`MaterialTapTargetSize.padded`, así que **el área táctil sigue siendo de 48**
aunque la altura pintada sea 40. «Siguiente» y «Anterior» del recorrido no se
tocan porque ya iban sin alto forzado.

## Iconos: tres tonos que eran el mismo

Los tres cuadros de Especies iban en turquesa, menta y cian. Medidos:

| | matiz | contraste del icono sobre la tarjeta |
|---|---|---|
| menta | 172° | 1.26:1 |
| turquesa | 178° | 1.34:1 |
| cian | 186° | 1.31:1 |

**14° entre los tres**, que es lo que hacía que se leyeran como el mismo color
repetido. Se reparten por la rueda dejando el aqua de marca en la especie
principal: turquesa 178°, violeta 242° y rosa 326°, o sea 64° y 84° de
separación. En Planes pasaba lo mismo entre Individual (242°) y Clínica (256°),
también 14°; Clínica pasa al rosa.

Comparación de los tonos: [tonos-iconos-bienvenida.png](tonos-iconos-bienvenida.png)

**Queda un problema aparte, que no se tocó porque afecta a toda la app**: la
familia aqua se pinta a 1.3:1 sobre la tarjeta clara, por debajo del 3:1 que
pide WCAG para elementos gráficos. Es el motivo de que esos iconos se vean
lavados, además de parecidos. No hay en la paleta ninguna terna que separe el
matiz **y** supere 3:1 a la vez: todo lo que llega a 3:1 está apiñado entre 212°
y 264°. Arreglarlo de raíz es oscurecer el glifo dentro de `VetIconBox`, que se
usa en `VetSectionHeader` y en media app, así que se deja a decisión de Ale.

## Logotipo del acceso: 100 → 132

`VetDosisBrand(large: true)` dibujaba la marca a 100. Era 132 hasta el commit
`1e021b6`, «Integra acceso compacto y ajustes de Inicio y Cálculo (#127)», que
la bajó al compactar el acceso. Vuelve a 132. El comentario de
`brand_mark.dart` seguía diciendo «se dibuja a 34 o 132», o sea que se quedó
obsoleto en aquel cambio y ahora vuelve a ser cierto.

## Comprobaciones

- `audit_overflow.py --fail-on-overflow`: 0 filas fuera del ancho de 360 dp.
- Ninguna prueba fija el alto de estos botones, los colores de la bienvenida ni
  el tamaño de la marca; se comprobó con `grep` sobre `test/`.
- Balance de delimitadores correcto en los tres archivos tocados.

## Pendiente

- **Sin compilar ni probar en teléfono**: no hay SDK de Flutter en el entorno.
  Las medidas salen de las capturas y del código, no de una ejecución. Falta
  `flutter analyze`, `flutter test` y ver el APK en el aparato.
