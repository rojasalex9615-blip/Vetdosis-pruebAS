# Secciones perdidas entre ramas · inventario

Fecha: 2026-11-19. Base comparada: `beta/profesores-20261115` en `0857dcd` (+ los dos commits de `fix/acuicultura-especie-obsoleta`).

Método: se descargaron **todas** las ramas de los dos remotos (118 en GitHub, 55 en GitLab) y se compararon contra HEAD a tres niveles: pantallas de `lib/core/app.dart`, archivos de `lib/` y secciones internas (`initialSection`). Lo que sigue es lo que salió de esa comparación, no una impresión.

## Resumen

A nivel de pantalla y de archivo, la beta **no ha perdido nada** de `main` ni de la rama de integración: es superconjunto de ambas. Lo que falta son **dos secciones que nunca llegaron a entrar**, más tres archivos que son reemplazos deliberados.

| Hallazgo | Estado | Dónde vive |
|---|---|---|
| OCR de reportes de laboratorio | **Perdido**, nunca entró | `origin/integracion/todo-en-uno-muse-20261118` |
| Constantes clínicas por especie (asset + carga) | **Inerte en la beta**: hay código, falta el dato | idem |
| Pantalla «Notificaciones» con notas y recordatorios propios | Reemplazada | `personal_space` |
| `auth_glass.dart` | Reemplazado | `vet_ui` |
| `vademecum_panel.dart` | Reemplazado | `doses/presentation/vademecum_screen.dart` |

## 1. OCR de reportes de laboratorio — perdido

La beta **exige teclear a mano** los valores de un análisis. En la rama Muse hay un lector que toma una foto del reporte, la pasa por OCR **en el dispositivo** (`google_mlkit_text_recognition`, sin enviar la imagen a ningún servidor) y vuelca los valores como texto editable para que el profesional los corrija.

Lo llamativo: la dependencia `google_mlkit_text_recognition: ^0.15.1` **ya está en el `pubspec.yaml` de la beta** (línea 26), pero el código que la usa no. Se paga el peso de la dependencia sin tener la función.

Archivos ausentes (todos de `origin/integracion/todo-en-uno-muse-20261118`, commit `82fe009`):

| Archivo | Líneas | Qué hace |
|---|---|---|
| `lib/modules/laboratory/data/lab_report_reader.dart` | 35 | Cámara/galería + `TextRecognizer`; devuelve el texto |
| `lib/modules/laboratory/domain/lab_report_ocr.dart` | 114 | Convierte el texto en filas candidatas (`LabReportCandidate`) |
| `lib/modules/laboratory/domain/lab_reference_resolver.dart` | 69 | Resuelve la referencia de cada analito |
| `lib/modules/laboratory/presentation/lab_screen.dart` | +193 | Botones «Tomar foto del reporte» y «Elegir imagen de la galería» |
| `lib/modules/laboratory/presentation/lab_view_model.dart` | +52 | Cableado del lector |
| `lib/modules/laboratory/domain/lab_repository.dart` | +6 | `LabAnalyte.species` |

El parser es cuidadoso y merece conservarse tal cual: descarta líneas con coma ambigua (`\d,\d`, que sería separador de miles), descarta «Página 1 de 3», descarta números sin letras delante (años, folios) y, cuando reconoce un analito del catálogo, usa **su** nombre y **su** unidad para que aparezca el rango de referencia.

## 2. Constantes clínicas por especie — a medias

Esto es lo más delicado, porque **parece hecho y no lo está**.

En la beta existe `lib/modules/forms/clinical/vital_reference_catalog.dart` y `clinical_vitals_screen.dart` acepta un parámetro `referenceCatalog`. Pero:

- El asset `assets/clinical/vital_references.v1.json` **no está**. La carpeta `assets/clinical/` sí está declarada en `pubspec.yaml`, así que basta con dejar el archivo.
- Nadie pasa `referenceCatalog:` al construir la pantalla (`git grep "referenceCatalog:"` no devuelve nada en HEAD).
- Falta `vital_reference_repository.dart`, que es quien carga el asset.

Resultado: la función de referencia por especie está **inerte** en la beta. El código compila y los tests pasan porque el parámetro es opcional y siempre vale `null`.

El asset perdido trae 14 referencias: **canino y felino**, con FC, FR, temperatura, TLLC y presión sistólica/diastólica. Las 14 están marcadas `"status": "unverified"`, con su `source` y `note` (por ejemplo «Portafolio de rotativo p.60, cuadro 12»). O sea: son datos en revisión, y el diseño ya lo contempla con el banner de «Dato en revisión».

## 3. Por qué no entró

El commit `82fe009` («Constantes clínicas con referencia por especie y extracción de análisis por foto») solo está en `origin/integracion/todo-en-uno-muse-20261118`. Comprobado:

```
git merge-base --is-ancestor 82fe009 HEAD   ->  NO
git branch -r --contains 82fe009            ->  solo esa rama
```

La rama Muse parte de `bc893d7` (18 nov), **anterior** a la acuicultura. Por eso su diff contra la beta «borra» 295 líneas de `aquaculture_species.dart`: no las borra, es que no las tenía. **No hay que fusionar la rama entera**; hay que llevarse 5 archivos nuevos y el cableado de 4 existentes.

Además, esa rama **solo está en GitLab** (`origin/integracion/todo-en-uno-muse-20261118`); no existe en GitHub. Quien trabaje solo desde el espejo de GitHub no la ve. Lleva el tag `beta-20261118-muse-estadisticas`.

De Muse **sí** se integró una parte: el commit `011bf13` («Integra Estadisticas y atajos de Ajustes de Muse») está en la beta. Lo que quedó fuera es justo el commit `82fe009`.

## 4. Lo que NO está perdido

Verificado uno por uno, para no reabrir trabajo cerrado:

- **Notificaciones con notas y recordatorios propios.** La rama `feature/notificaciones-personales-20261106` tenía una bandeja donde el usuario creaba sus notas y recordatorios, con almacén local en Sembast. En la beta eso vive en `personal_space` (`PersonalNote` con `reminder`, `remindAt`), y la campana actual (`inbox.dart`) agrega avisos de otros. Son dos diseños distintos: el segundo sustituye al primero. No falta nada.
- **`auth_glass.dart`**: paleta de las pantallas de acceso, del 6 nov. Sustituida por `vet_ui`.
- **`vademecum_panel.dart`**: del 23 oct. Sustituida por `vademecum_screen.dart`.
- **Pantallas de `main` e integración**: la beta las tiene todas, más «Exóticos».

## Cómo recuperarlo

Los archivos se sacan de la rama sin fusionarla:

```bash
git show origin/integracion/todo-en-uno-muse-20261118:lib/modules/laboratory/domain/lab_report_ocr.dart \
  > lib/modules/laboratory/domain/lab_report_ocr.dart
```

Para `lab_screen.dart`, `lab_view_model.dart`, `clinical_vitals_screen.dart` y `app.dart` **no** conviene copiar el archivo entero: son los que traen el resto de Muse encima. Hay que aplicar solo el trozo del OCR y de la carga del catálogo.

Pendiente de decidir con Ale: si se recupera ahora o se deja anotado. No se ha tocado código en esta auditoría.
