# Validación integral candidata — VetDosis Pro · Pequeñas especies

Fecha: 28-oct-2026 UTC. Estado: **integración temporal validada localmente; NO lista para distribución**.

Repositorio: `rojasalex9615-blip/Vetdosis-pruebAS`.
Rama: `integration/pequenas-beta-validation-20261028`.
Código evaluado: `d2c7228eab0f0a2960636316d9661411e7ce7191`.
Main observado, sin modificar: `46abfe196497cf4a168b60831b9aad835c29a898`.
Base funcional/visual: #59 `2d7c3af97763019c63ee81657eea88eea086da10`.

## Composición y dependencias

Se inventariaron **48 PR abiertos** con sus puntas, bases, CI y hilos de revisión. **38 puntas exactas** son ancestros de esta integración. La evidencia por PR está en [pr-dependencies.md](pr-dependencies.md) y [pr-review-snapshot.json](pr-review-snapshot.json).

- La cadena #26 → base anterior de #28 → #35 → #36 → #37 → #39–#53 → #55–#59 ya estaba contenida en #59; no se volvió a aplicar.
- Se fusionó **solo en esta rama temporal** #38 `f7d670e89f80c685592793cf156d063d49c65b1c`: auditoría y prueba de carrera de selección de clínica.
- Se incorporaron #2 `1444f3551cc99327fe668c7648f1755e991a34f4` (dos clínicas sintéticas) y #4 `4006d03ac0503e3d898b6961319ae8b832df66f1` (CI de permisos de operaciones).
- La punta actual de #28 `80b845881519012bbf26640e875e2cfd54d4d3d5` diverge. La normalización de búsqueda ya existe como `normalizeDoseSearch`; se descartó el cherry-pick conflictivo para conservar esa implementación y su cobertura. No se afirma que la punta exacta de #28 esté fusionada.
- **#20 se excluyó**: conflictos en tres archivos de Auth y código Dart mal formado en `auth_repository.dart`, confirmado por parser (cadena RegExp sin cerrar y declaraciones duplicadas). Sus pruebas/CI individuales no eran satisfactorias. Requiere un PR reparado y nueva conciliación con Auth/TeamDuty antes de incorporar el registro legal.
- #3/#14 son auditorías/handoffs históricos independientes. #5/#10/#11/#18 son variantes previas que no se aplicaron ciegamente. #9/#17 preparan staging privado/investigación, con su propio orden SQL; no se convirtieron en catálogo clínico activo.
- El repositorio distinto `Vet-dosis-pruebas` tiene nuevos documentos hasta `80862c9`; son evidencia de investigación, no nuevas pautas automáticas integradas. Se conserva la procedencia previa `b64ff80` de los componentes portados.

## Qué funciona en las pruebas realizadas

Las pruebas de Flutter usan repositorios simulados y los SQL ejecutan RPC/funciones reales sobre PostgreSQL 17 efímero con datos sintéticos y `--network none`. Estos resultados no acreditan HTTP/RLS/Storage reales ni instalación en Android.

| Recorrido / área | Evidencia ejecutada | Resultado y límite |
|---|---|---|
| Agenda → Pacientes | `agenda_capture_test`, `appointment_care_test`, contactos/historia; cinco fixtures SQL de cita/carnet/contactos | Enlace al paciente, búsqueda con respuestas tardías, apertura de expediente, identidad y cierre según tipo de cita. Fixtures aprobados; falta repetir con dos sesiones reales. |
| Pacientes → Consulta | `clinical_test`, `clinical_screen_contract_test`, `independent_clinical_cases_test`; cadena SQL 13C–13M | Permisos explícitos, responsable, procedimiento y registros independientes. No se presume habilitación por el nombre del rol. |
| Consulta → Cálculos | `recorded_weight_calculation_test`, `commercial_recorded_weight_test`, `calculator_family_test` | Peso persistido revalidado; cambios de sesión/fuente/entradas invalidan resultados. Las dosis se confirman; no se eligen tratamientos por inferencia. |
| Cálculos → Receta → Hospitalización | `prescription_workflow_test`, `prescription_standing_test`, `prescribing_test`, `hospital*`; SQL 13H/14D–14L | Preparación y firma individual, permisos, doble confirmación y acceso a indicaciones. **No hay una única prueba remota/Android que atraviese toda la cadena, ni creación automática de receta/orden desde el resultado aritmético.** |
| Inventario/ventas/caja | Suites de inventario, devoluciones y abonos; SQL financiero + personal combinado | Costos, cantidades, saldos, reintentos y carreras de cobros/devoluciones/reintegros aprobados en local. Los contratos nuevos faltan en el servidor actual. |
| Dos clínicas | #38 Flutter y SQL de #2; pruebas de aislamiento de hospital/pacientes/preferencias/archivos | Selección mantenida durante refresco; revocación y respuesta antigua no recuperan acceso. Dos cuentas clínicas sintéticas no acceden al workspace ajeno. No equivale a un ensayo HTTP de todas las tablas/RLS. |
| Respaldos/archivos | `drive_backup_test`, `backup_protection_test`; permisos de backup/Storage; restauración 13Q–13V | Cifrado, integridad, estados y recuperación de tutores/pacientes probados localmente. No se ejecutó OAuth real ni recuperación integral PostgreSQL+Storage desde una copia externa real. |
| PDF/firmas | 15 pruebas Node del renderer real, PDF preventivo Flutter | PDF parseable, Unicode, firmas, identidad, folio capturado y datos congelados validados. Falta la función remota, descarga autorizada y compartir/imprimir en Android. |
| Avisos hospitalarios | SQL de canales/historial/turnos y pruebas Node de transporte/auth/token; Flutter | Revocación, cambio de destinatario, leases agotadas y payloads probados con proveedores simulados. Falta recepción FCM/WhatsApp real, app cerrada/reinicio y permisos del teléfono. |

Además, `run_small_animal_integration.sh` instala en **una misma base efímera** la cadena clínica/prescripción/caja, migraciones financieras/personales, Storage, hospitalización, preferencias, frascos y adaptadores de pacientes/agenda. Comprueba existencia conjunta de contratos, conservación del workspace financiero y ausencia de ejecución anónima en los endpoints comprobados. **No es un instalador de Supabase ni demuestra la cadena clínica completa con acciones HTTP.** Los demás runners conservan sus propios fixtures y carreras de concurrencia.

## Fallos encontrados y correcciones

| Origen | Fallo comprobado | Tratamiento en esta rama |
|---|---|---|
| #38 pendiente de integración | Un refresco de membresías podía restaurar la clínica seleccionada al iniciar la solicitud | Incorporado el contador de selección y sus pruebas de respuestas tardías/revocación. |
| #36 / restauración | `run_restore_preview_staging.sh` fallaba por ausencia de `public.preventive_evidence` en el montaje | Añadidos adaptadores de carnet y búsqueda antes de la prueba de permisos, igual que el runner de backups. Fallo inicial preservado en `initial-checks-before-fixture-fix.json`; repetición aprobada. |
| #56 Major | Acciones Neu oscuras con fondo pastel claro y letras blancas | Fondo oscuro en CalculatorActionButton; tinta según luminancia en el botón soft compartido para las variantes que lo usan directamente. Contraste ≥4.5 verificado para ocho identidades en ambos modos; callbacks conservados. Capturas finales en `calculators/`. |
| #59 Minor / Trivial | Color seleccionado de Clásico sobreescrito y prueba de GlobalKey insuficiente | Clásico conserva icono heredado; prueba comprueba que sobrevive el mismo elemento al alternar glow. |
| #51 Minor | Incompatibilidad de esquema de devolución mostrada como error de permisos | Mensaje explícito de app/servidor incompatibles; esquemas 2 y 4 rechazan envío sin escritura. |
| #58 Minor | Ruta predeterminada de capturas reutilizaba una entrega anterior | Ruta predeterminada corregida al directorio de jerarquía de glow. |
| Preparación del runner PDF | Faltaban paquetes npm instalados en el worktree nuevo | `npm ci --prefix supabase --ignore-scripts` usando package-lock existente; 15 pruebas reales aprobadas. Sin cambiar dependencias del proyecto. |

No se resolvieron automáticamente hilos originales de GitHub: los cambios deben revisarse sobre el conjunto. Algunos hilos históricos de #26/#28/#35/#44–#46 ya tienen correcciones descendientes; el número de hilos abiertos no acredita vulnerabilidad vigente ni aprobación. Siguen pendientes la cobertura más fuerte de replays financieros sobre turno cerrado (#51), la advertencia documental de retención de auditoría (#50) y la incorporación de ciertas aserciones de preview a la CI normal (#55).

## Diferencias con Supabase Pruebas y bloqueos

Se consultó **solo `pg_catalog`** del proyecto Pruebas, sin cuentas, pacientes ni escrituras. [remote-contracts-readonly.json](remote-contracts-readonly.json) conserva los nombres realmente usados por los clientes y la evidencia de presencia/EXECUTE anónimo. La consulta no garantiza RLS, definición equivalente ni datos correctos.

Presentes en la consulta: módulos, clínica, receta individual, automatización hospitalaria, enrolamiento/reemplazo de destinos, preferencias, biblioteca de referencia y cuenta de comisiones. **Ausentes**:

- `inv_credit_accounts`, `inv_sale_collect`: #46/#51 no operan íntegramente en el backend actual.
- `inv_sale_return_workspace`, `inv_sale_return_v3`: #45/#46/#51 no están desplegados.
- `ops_commission_recovery`: #44/#51 no están desplegados.
- `ops_staff_medical_workspace/write/directory/view`: #50 no está desplegado.
- `beta_registration_legal`: #20 tampoco está instalado.

El paquete atómico existente solo enumera 23 candidatos esenciales (13A–13P y 13W); **no instala todo el conjunto 14*/migraciones nuevas**. No se debe ejecutar «todos los SQL por orden alfabético»: existen prefijos duplicados de dominios distintos e índices concurrentes que deben ir fuera de transacción. El runner combinado es un ensayo de compatibilidad de esquema sobre fixtures, no un plan de actualización remoto autorizado.

Bloqueos para distribución:

1. Reparar y reconciliar #20; verificar publicación legal/registro antes de admitir cuentas nuevas.
2. Preparar un plan remoto versionado para las funciones nuevas, comparar definiciones/grants/RLS, someterlo a revisión y pedir autorización antes de aplicarlo. No se desplegó nada en esta entrega.
3. CodeRabbit debe revisar el conjunto integrado. La solicitud y su acuse no equivalen a aprobación completa; los PR previos siguen pendientes de integración a main.
4. Ejecutar QA con dos clínicas ficticias por HTTP y en una APK concreta. No hay evidencia nueva de uso en teléfono.

Fuera de integración efectiva: RPBI todavía no es módulo operativo; bandeja/campana y dashboard personal de #54 son diseño propuesto; Exóticos/Producción siguen expuestos en algunas pantallas y no se certifican para esta beta. Las 662 fichas de investigación y el padrón SENASICA no equivalen a 662 pautas automáticas verificadas por especie/presentación; la conciliación regulatoria sigue pendiente.

## Resultado de ejecución

Ver `local-checks.json` para comandos, códigos de salida y tiempos. La primera batería Flutter de esta integración pasó **668 pruebas, 1 omitida**. Tras corregir la variante soft adicional pasaron nueve regresiones focalizadas y cuatro renderizados. La **repetición completa final también pasó 668 pruebas, 1 omitida**, con análisis limpio, sobre el código indicado arriba. El commit posterior `2d31d4f453469d7b6b9ccfc7e99fb9f99b24da09` añade únicamente la ejecución CI local; el manifiesto de ejecución identifica ambas referencias.

17 grupos de comprobación local aprobados: 13 grupos SQL/fixtures, 85 pruebas Python de Supabase, 10 de herramientas Android (1 omitida por entorno), pruebas Node de hospitalización y 15 de PDF. La omisión Android no se contabiliza como prueba de teléfono. Análisis Flutter limpio. La cifra de grupos no es un conteo de aserciones SQL.

## APK y siguiente paso

**No se generó APK candidata**: los contratos remotos faltantes y el registro legal incompatible impiden dar por validado el conjunto conectado. Además este entorno no tiene Android SDK. No se ejecutó el workflow de APK firmada, porque su último paso publica metadatos beta en Supabase y esa escritura no está autorizada aquí. Ninguna APK previa representa esta rama/SHA.

Después de resolver bloqueos, usar una compilación solo de artefactos (sin publicación/deploy), identificar repositorio/rama/SHA, flavor beta, package ID, versionCode, certificado y SHA-256 del APK. Aplicar [android-qa.md](android-qa.md) sobre dos clínicas ficticias. Únicamente tras esa evidencia se evalúa distribución.

Para Claude: revisar primero la tabla de recorridos y las diferencias de backend; organizar hallazgos por implementado en fuente / probado localmente / revisado / integrado en main / desplegado / probado en Android. El tablero #31 es la referencia compartida; no se atribuye a Claude lectura, aceptación o revisión todavía.

## Reproducción local

```sh
flutter pub get
flutter analyze
flutter test --no-pub
npm ci --prefix supabase --ignore-scripts
python3 scripts/validation/validate_small_animals.py --output /tmp/vetdosis-validation
flutter test --no-pub test/previews/capture_calculator_pastels.dart --dart-define=CALCULATOR_PREVIEW_DIR=/tmp/vetdosis-calculators
```

Los comandos de validación anteriores no aplican cambios a Supabase. Requieren Docker local, Flutter 3.47.6, Python, Node y `pdftotext` para los PDFs. Los runners SQL conservan bases desechables y sus datos sintéticos; no usar sus fixtures contra una base remota.
