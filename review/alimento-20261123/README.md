# Inventario de alimento — 23 de noviembre de 2026

El Dashboard Pecuario enseñaba una conversión alimenticia de 1.45, un costo de
6.85 por litro de leche y unos silos al 71 %. Ninguna de esas cifras salía de
la granja de nadie: estaban escritas a mano en el código. Esta ronda las
sustituye por un inventario de alimento de verdad y borra las que sobraban.

## Qué se puede hacer ahora

1. **Catálogo de alimentos.** Nombre, tipo, unidad de compra, kg por unidad y,
   si se conocen, materia seca y proteína. Admin y MVZ.
2. **Silos y bodegas.** Dónde se guarda y cuánto le cabe. Admin y MVZ.
3. **Movimientos.** Compra, consumo, merma y ajuste. También el auxiliar, que
   es quien suele cargar el camión.

De ahí salen solas tres cosas que antes eran adorno: las existencias por silo,
el costo real del kilo y la conversión alimenticia por lote.

## Las decisiones que conviene conocer

**Todo se guarda en kilos.** La unidad de compra sirve al capturar —un costal,
una paca, una tonelada— y el formulario enseña la conversión antes de guardar,
para que nadie descubra después que apuntó 40 sacos como 40 kilos.

**El signo lo pone el servidor.** Una compra suma, un consumo y una merma
restan, y un ajuste respeta lo que se le diga. La app nunca manda un número
negativo: si el signo dependiera de la pantalla, tarde o temprano una pantalla
se equivocaría.

**Las salidas se valoran al promedio ponderado.** Si entraron 10 000 kg a 7.50
y luego 2 000 a 9.00, el kilo que sale vale 7.75, no el último precio pagado.
Es la cuenta que hace un contador y la que hace que el costo por litro cuadre.

**El precio solo se pide en la compra.** Pedirlo en un consumo invita a
teclear un número cualquiera.

**La existencia negativa se muestra, no se esconde.** Si el sistema dice
−40 kg, es que falta registrar una compra. Recortar el número a cero borraría
justo la señal que avisa del error.

**Cuando el dato no alcanza, se dice.** La conversión alimenticia necesita
kilos de alimento y kilos producidos. Si falta alguno, sale el motivo en vez
de un número. Un «sin dato» es honesto; un 1.45 inventado, no.

**La materia seca es opcional y eso se respeta.** Si un solo alimento del lote
no la declara, el total en materia seca queda en nulo: una suma a medias se
parece demasiado a una suma completa. La conversión se calcula entonces en
kilos tal cual, con su aviso.

## El catálogo de ejemplo: borrado

`speciesDataCatalog` guardaba, por especie, costos, conversión alimenticia,
silos, instalaciones, curvas, lotes y alertas de una granja de 480 vacas con
una «Vaca #402» enferma. Una ronda anterior ya lo había desconectado de la
pantalla, así que no se veía, pero seguían siendo 133 valores inventados
esperando a que alguien los reconectara —y ahora había un panel de silos nuevo
al que conectarlos—.

Se eliminaron esos 133 valores, las seis clases que solo existían para
sostenerlos (`SiloData`, `FacilityData`, `CalendarEvent`, `WithdrawalAlert`,
`BatchData`, `ProductionAlert`) y el import que ya no usaba nadie: 434 líneas
menos. Del catálogo sobrevive lo único que era cierto, las **constantes
vitales** por especie —temperatura, frecuencia cardíaca, respiratoria—, que son
rangos de referencia publicados y no dependen de la granja de nadie. Dos
pruebas nuevas vigilan que siga siendo así.

## Comprobaciones

En la base, con datos reales y luego borrados, **16 de 16**: alta y rechazo de
duplicados, promedio ponderado a 7.8333, el signo que pone el servidor, el
consumo sin lote y contra lote cerrado, guardar dos veces el mismo movimiento
sin duplicarlo, fecha futura, compra sin precio, existencias, conversión con y
sin materia seca, costo del lote y —la importante— **escritura directa en las
tablas bloqueada**: solo se puede entrar por los procedimientos, que son los
que validan.

En la app, 34 pruebas sobre conversión de unidades, existencias, costos,
permisos por rol, traducción de errores y los formularios. Las cuentas de cada
aserto se recalcularon aparte antes de darlas por buenas.

Aquí no hay Flutter instalado, así que las pruebas no se ejecutaron: se
revisaron los contratos uno a uno contra el código —constructores, parámetros,
enums, nombres de componentes— para no inventar ninguno, más el auditor de
desbordamiento, que da **0 filas** que no quepan en un teléfono de 360 dp.

## Lo que falta

- Las pruebas de Flutter no se han corrido todavía; hay que lanzarlas donde
  exista el toolchain.
- El Dashboard Pecuario aún no pinta la conversión alimenticia ni el costo por
  litro con estos datos: el inventario ya los calcula, falta llevarlos a esa
  pantalla.
- En exóticos no se tocó nada: ahí la ración es individual y ya vive en sus
  propios registros.
