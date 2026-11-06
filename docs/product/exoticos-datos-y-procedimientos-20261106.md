# Exóticos y silvestres: qué datos necesita la app y con qué se trabaja

**Fecha:** 2026-11-06
**Autor:** Solar Pro 4, bajo la identidad de Buffy que asigna la plataforma
**Estado:** propuesta de requisitos. **Sin revisión MVZ.** No siembra datos clínicos en assets ni en Supabase.
**Alcance:** qué información pide el área de exóticos, qué campos debe capturar la ficha y qué procedimientos puede guiar la app con seguridad. Complementa —no sustituye— la propuesta de módulo del PR #102.

> **Aviso que debe acompañar a todo el módulo:** los valores de este documento son **citas de fuentes publicadas**, no recomendaciones revisadas. Ninguno debe mostrarse en la app como cálculo operativo hasta que un MVZ lo valide con fuente y quede registrado `evidence.verified`.

---

## 0. La pregunta de Ale: ¿los cálculos metabólicos son de exóticos?

Sí, y por una razón concreta: en perro y gato la dosis en mg/kg está establecida por especie, y el cálculo interesante es el de siempre (fluidos, dosis, CRI). En exóticos **casi nunca hay datos farmacocinéticos por especie**, así que el peso metabólico pasa a ser la herramienta de trabajo. Se usa en dos familias distintas, que conviene no mezclar:

**a) Energía y nutrición (uso sólido).** El requerimiento energético en reposo se calcula con el peso elevado a 0,75 y una constante `K` que cambia por taxón:

| Grupo | Constante `K` | Fuente |
|---|---|---|
| Ave paseriforme | 129 | ARAV 1994 (Hainsworth) |
| Ave no paseriforme | 78 | ARAV 1994 |
| Mamífero placentario | 70 | ARAV 1994 |
| Mamífero marsupial | 49 | ARAV 1994 |
| Reptil | 10 | ARAV 1994; Merck confirma `K = 10` para la mayoría de reptiles |

`MEC (kcal/día) = K × W(kg)^0,75`. A eso se le aplican factores de estado (sano, debilitado, lactante, joven) según el mismo material. Este sí es un cálculo que la app puede hacer bien, porque es dimensional y la constante tiene fuente.

**b) Extrapolación alométrica de dosis (uso discutido).** Merck describe `costo energético mínimo = K(W^0,75)` y `costo energético específico = K(W^-0,25)` para estimar dosis e intervalo cuando no hay datos de la especie. Pero la literatura es explícita sobre sus límites:

- Visser y Oster (2018): la alometría «falla en fármacos con metabolismo hepático significativo y **no puede extrapolarse a aves ni reptiles**»; el escalado lineal en mg/kg «no contempla diferencias de metabolismo y a veces produce toxicidad».
- Un estudio en félidos silvestres (2016) concluyó que las dosis anestésicas calculadas por alometría desde el gato doméstico «**no deben aplicarse**» a esas especies.
- El debate 0,75 frente a 0,67 sigue abierto en la propia literatura de escalado.

**Conclusión para la app:** el peso metabólico sirve para **energía y ración**, y como dato comparativo. **No** debe convertirse en un factor automático de dosis. El texto que ya muestra la app —«Peso metabólico aproximado… No es una dosis ni un factor automático de escalamiento»— es correcto y no hay que suavizarlo. Esto contradice la tabla `1.0x / 0.8x / 0.5x / 1.2x` del PR #102 y es la razón por la que no debería implementarse.

---

## 1. Por qué exóticos no se resuelve copiando perro y gato

| Diferencia | Consecuencia en la app |
|---|---|
| Ectotermia (reptiles, peces, anfibios) | La temperatura corporal **no es una constante fija**: es un dato medido y depende del gradiente del terrario. Un rango «normal» único es un error clínico. |
| Peso en gramos | Muchos pacientes pesan 30–200 g. Fórmulas y campos deben trabajar en gramos sin redondear a kg. |
| Metabolismo por taxón | Constantes de energía y tasas de fluidos distintas entre ave, reptil, pequeño mamífero y pez. |
| Ambiente como causa de enfermedad | La mayoría de las consultas de reptiles se explica por dieta o alojamiento incorrectos: sin historia de manejo, la ficha no sirve. |
| Datos por especie escasos | Todo valor necesita fuente explícita y estado de revisión; no hay «promedio de la especie». |
| Legalidad de la especie | Hay especies con protección legal; la ficha debe poder marcarlo sin convertirse en asesoría jurídica. |

---

## 2. Datos de referencia que hay que tener (bloques)

Cada bloque necesita, como mínimo: **especie o taxón, parámetro, valor o intervalo, unidad, condición (edad, sexo, método), fuente y estado de revisión.**

1. **Constantes fisiológicas por especie.** Frecuencia cardiaca y respiratoria, temperatura, peso adulto, longevidad. *Ya hay 166 filas de `EXÓTICOS / FISIOLOGÍA` transcritas en `vetdosis_reference_staging.raw_intake_rows`, pendientes de revisión.*
2. **Intervalos de laboratorio por especie y método.** Hematología y bioquímica. Dependen del analizador y del laboratorio emisor (Cornell, eClinpath): un intervalo sin método no es interpretable.
3. **Energía.** Constante `K` por taxón y factores de estado.
4. **Fluidos por taxón.** Mantenimiento, rehidratación, shock, ruta y tiempo de reposición. Las cifras publicadas **no coinciden entre sí**, lo que refuerza que cada fila lleve su fuente.
5. **Fármacos.** Especie, vía, dosis, intervalo, concentración, presentación, indicación y contraindicaciones; fuentes de referencia: Carpenter's Exotic Animal Formulary y BSAVA Small Animal Formulary Part B.
6. **Manejo ambiental por especie.** Gradiente térmico día/noche, punto de asoleamiento, humedad, UVB, fotoperiodo, sustrato y tamaño mínimo de encierro (tablas de Merck).
7. **Peces ornamentales.** Amonio, nitrito, nitrato, pH, dureza, temperatura, salinidad y ciclo del nitrógeno.

### Ejemplo de por qué la fuente es obligatoria: tasas de fluidos

| Taxón | Mantenimiento citado | Fuente |
|---|---|---|
| Reptiles | 5–15 mL/kg/24 h (rehidratación 30–40) | Merck, Clinical Procedures for Reptiles |
| Reptiles | 10–30 mL/kg/día | Material de fauna silvestre (FWRA, NC Wildlife) |
| Aves | 50–100 mL/kg/24 h | MSD/MSD Vet Manual, Management of Pet Birds |
| Aves | 60–100 mL/kg/día | NC Wildlife |
| Pequeños mamíferos | 80–100 mL/kg/día | dvm360 (Mitchell) |
| Mamíferos en general | 50–60 mL/kg/día | NC Wildlife |

Todas son publicadas y **ninguna es «la» cifra**. Si la app muestra una sola, tiene que decir de dónde sale; si muestra varias, tiene que dejar claro que son alternativas y que la elección es del MVZ.

---

## 3. Campos de la ficha clínica por taxón

**Identificación**
- Taxón y especie (no «exótico» genérico), variedad o fase, nombre.
- Peso en gramos y fecha de pesaje; longitud o talla cuando aplique.
- Sexo y **método de sexado** (muchas especies no se sexan a simple vista).
- Edad estimada y origen: criado en cautiverio o capturado; si es especie protegida, marca de estatus legal.

**Manejo (obligatorio, no opcional)**
- Tipo, material y medidas del encierro; ubicación; compañeros de encierro.
- Sustrato y frecuencia de limpieza; desinfectante usado.
- Fuentes de calor y su control; **gradiente día y noche**; punto de asoleamiento.
- Humedad y cómo se mide; fotoperiodo; UVB: tipo de lámpara, distancia, fecha de última renovación.
- Dieta, marca, frecuencia, suplementos (calcio, vitaminas), agua y frecuencia de cambio.

**Especie-específico**
- Reptiles: fecha de última ecdisis y problemas de muda; heces y uratos; inmersión/baño.
- Aves: muda, plumaje, capacidad de vuelo, vocalización, nivel de estrés al manejo.
- Peces: volumen del sistema, filtración, cambios de agua, parámetros medidos y fecha.
- Pequeños mamíferos: dentición y desgaste, coprofagia, temperatura ambiente.

**Examen**
- Temperatura medida y **temperatura del recinto**, no solo «temperatura normal».
- Peso y condición corporal por escala del taxón.
- Muestra de laboratorio: sitio de venopunción y **volumen extraído frente al máximo seguro** (reptiles: volemia ≈ 5–8 % del peso, 70 mL/kg; extraíble ≈ 10 % de la volemia).

---

## 4. Procedimientos que la app puede guiar (sin inventar dosis)

1. **Historia dirigida por taxón** con los campos del punto 3, incluido un recordatorio de que sin manejo no se interpreta el cuadro.
2. **Plan de fluidos**: mantenimiento + déficit por porcentaje de deshidratación + pérdidas, repartido en días según taxón, con ruta (oral, SC, intracelómica, intraósea) y aviso de calentar el fluido.
3. **Energía y ración**: MEC con `K` por taxón y factor de estado; conversión a cantidad de alimento con la densidad energética del producto.
4. **Volumen sanguíneo máximo seguro** por peso, para no sobreextraer en pacientes de 30 g.
5. **Dilución y dosis desde concentración**: mg/kg, concentración de la presentación, volumen a administrar (la app ya tiene el cálculo y la presentación verificada como requisito).
6. **CRI** con velocidad, volumen y duración (ya existe `cri`).
7. **Agua en peces**: interpretación de amonio, nitrito, nitrato, pH y temperatura, con el ciclo del nitrógeno como contexto.
8. **Checklist de manejo**: UVB caducado, gradiente insuficiente, humedad inadecuada, sustrato peligroso, dieta monótona.
9. **Bitácora de peso y muda** con gráfica, que en exóticos suele ser el signo más sensible.

Lo que la app **no** debe hacer: extrapolar dosis automáticamente por alometría, proponer un rango único de constantes, o convertir «especie parecida» en sustituto de la fuente.

---

## 5. Qué existe ya en VetDosis y qué falta

| Pieza | Estado real en `main` (`cea30b6`) |
|---|---|
| Cálculo de fluidos | Existe (`fluids`), con referencias verificadas como requisito |
| CRI | Existe (`cri`) |
| Agua / producción | Existe (`water`), orientado a producción, no a peces ornamentales |
| Ajuste por especie | Existe (`adjustment`) y exige referencia `ajuste` verificada, factor coincidente y rango verificado |
| Peso metabólico en exóticos | **Cableado en la interfaz** (`calculation_screen.dart:264`), pero `metabolic` no está entre los 6 cálculos del catálogo y no hay referencias de tipo `metabolico` |
| Constantes de exóticos | 166 filas transcritas en Supabase, **pendientes de revisión**; la biblioteca las muestra, el catálogo de cálculo no las usa |
| Datos de fármacos | `assets/clinical/catalog.v1.json` vacío (`farmacos: []`, `fuentes: []`) |
| Puente revisión → catálogo | **No existe** |

Es decir: el trabajo pendiente de exóticos es de **datos con fuente y de revisión**, no de pantallas nuevas.

---

## 6. Avisos claros de «no revisado» (lo que pidió Ale para los revisores)

Requisitos mínimos para que un profesor pueda probar la app sin confundir borrador con producto:

1. **Etiqueta por valor**, no solo por pantalla: `Verificada · Fuente: …` o `Sin revisar · Fuente: …`, como ya hace el cálculo clínico.
2. **Banner persistente** en el módulo de exóticos: «Contenido en revisión clínica. No usar como recomendación de tratamiento.»
3. **Sin resultado cuando no hay fuente**: mantener el comportamiento actual («Sin referencias disponibles… no se proponen valores») en lugar de rellenar con cifras.
4. **Registro de quién validó**: fecha, revisor y fuente por entrada, para poder mostrar trazabilidad en la evaluación.
5. **Distinguir en la UI** lo que es cálculo dimensional (seguro) de lo que es recomendación clínica (requiere MVZ).

Esto permite entregar «la app terminada» en el sentido académico: completa en flujo y funciones, explícita en lo que aún no está validado.

---

## 7. Encuadre legal (para validar, no para implementar a ciegas)

México tiene normas que rozan el área y **no deben codificarse sin revisión de Ale y de un asesor**:

- **NOM-059-SEMARNAT-2010**: especies nativas en riesgo; importa para marcar especies protegidas y para el manejo de fauna silvestre.
- **Ley General de Vida Silvestre / UMA y SEMARNAT**: traslado, posesión y manejo de fauna silvestre.
- **NOM-064-ZOO-2000**: clasificación y prescripción de productos farmacéuticos veterinarios por nivel de riesgo de sus ingredientes activos.
- **NOM-033-SAG/ZOO-2014** y **NOM-062-ZOO-1999**: bienestar y métodos de eutanasia; la segunda es de animales de laboratorio y **no debe citarse como si aplicara a mascotas**.

Nada de esto es asesoría jurídica ni debe activarse como regla automática: el tablón tampoco autoriza activar reglas regulatorias.

---

## 8. Plan mínimo para que exóticos sea probable

1. Revisión MVZ de las 166 constantes de exóticos ya transcritas y publicación al catálogo con fuente y estado.
2. Cargar constantes de energía `K` por taxón (5 filas) con fuente, para activar el cálculo metabólico como **energía**, no como dosis.
3. Cargar tasas de fluidos por taxón (4–6 filas) con fuente y alternativa visible.
4. Ficha con los campos del punto 3, empezando por manejo.
5. Avisos del punto 6.
6. Fármacos: no cargar nada sin fuente; la tabla del PR #102 no entra.

---

## 9. Fuentes consultadas (2026-11-06)

- Merck Veterinary Manual — [Clinical Procedures for Reptiles](https://www.merckvetmanual.com/exotic-and-laboratory-animals/reptiles/clinical-procedures-for-reptiles): alometría `K(W^0.75)` y `K(W^-0.25)`, `K = 10` en reptiles, fluidos 5–15 / 30–40 / 3–5 mL/kg, inyección en el cuerpo craneal, dosis en quelonios por peso total.
- Merck Veterinary Manual — [Management and Husbandry of Reptiles](https://www.merckvetmanual.com/exotic-and-laboratory-animals/reptiles/management-and-husbandry-of-reptiles): gradiente térmico, asoleamiento +5 °C, noche −5 °C, fotoperiodo 12 h, UVB 290–300 nm, humedad mayor en ecdisis.
- MSD Veterinary Manual — [Management of Pet Birds](https://www.msdvetmanual.com/exotic-and-laboratory-animals/pet-birds/management-of-pet-birds): fluidos 50–100 mL/kg/24 h, calentar a 102–106 °F, sonda intraósea, buche 30 mL/kg 3–4 veces al día.
- MSD Veterinary Manual — [Management of Aquarium Fish](https://www.msdvetmanual.com/exotic-and-laboratory-animals/aquarium-fish/management-of-aquarium-fish): amonio, nitrito, nitrato y ciclo del nitrógeno.
- ARAV (1994) — [A review of allometric scaling with considerations for its application to reptile therapeutics](https://cdn.ymaws.com/members.arav.org/resource/resmgr/Files/Proceedings_1994/1994_15.pdf): constantes `K` por grupo y fórmula de Meeh `K(W^0.66)/102`.
- Visser M., Oster S. C. (2018) — [The Educated Guess: Determining Drug Doses in Exotic Animals Using Evidence-Based Medicine](https://pubmed.ncbi.nlm.nih.gov/29655466), *Vet Clin North Am Exot Anim Pract* 21(2):183-194: límites de la alometría.
- [Inconsistency of allometric scaling for dissociative anesthesia of wild felids](https://www.vaajournal.org/article/S1467-2987(16)30079-4/abstract), *Vet Anaesth Analg* (2016): las dosis por alometría «no deben aplicarse» a esas especies.
- [To scale or not to scale: the principles of dose extrapolation](https://pmc.ncbi.nlm.nih.gov/articles/PMC2737649): debate 0,75 frente a 0,67.
- WSAVA 2004, VIN — [Basic Approach to the Reptile Patient](https://www.vin.com/apputil/content/defaultadv1.aspx?id=3852208&pid=11181&print=1): volemia 5–8 % del peso (70 mL/kg), 10 % extraíble, POTZ, registro de alimentación, peso y ecdisis.
- FWRA 2025 — [Wildlife Fluid Therapy](https://fwra.org/wp-content/uploads/2025/02/fwra-2025-fluid-therapy-lab-final.pdf) y NC Wildlife (2024) — [Fluid therapy in wildlife](https://ncwildliferehab.org/wp-content/uploads/2024/01/Fluid-therapy-in-wildlife-finished.pdf): tasas por taxón, reparto del déficit en 48 h (aves) y 72 h (reptiles).
- dvm360 (Mitchell) — [Fluid therapy for exotic pets](https://www.dvm360.com/view/fluid-therapy-exotic-pets-it-important-consider-what-we-use-proceedings): 80–100 mL/kg/día en conejos y pequeños mamíferos exóticos.
- ExoCalc — [calc.avianexotics.vet](https://calc.avianexotics.vet/): referencia de lo que un revisor puede esperar de una calculadora de exóticos (extrapolación alométrica, plan de fluidos, CRI, interpretación de laboratorio).
- NOM-059-SEMARNAT-2010; NOM-033-SAG/ZOO-2014; NOM-064-ZOO-2000 (textos publicados en el DOF).

---

## 10. Límites de este documento

- **No es una guía clínica ni una revisión MVZ.** Es un inventario de requisitos con fuentes.
- **No ha revisado cada fila** de las 166 constantes de staging; solo su existencia y su estado `pendiente`.
- Las cifras citadas son **citas textuales** de las fuentes; no están contrastadas entre sí ni validadas para México.
- No se ha probado nada en dispositivo ni en la app; es documentación.
- La decisión de qué se carga y en qué orden es de Ale.
