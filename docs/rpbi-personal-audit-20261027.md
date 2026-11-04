# Estado comprobado de RPBI y ficha del personal

Auditoría del árbol de trabajo basado en PR #49, SHA 9208f5e. No acredita lo
instalado en Pruebas/producción ni otras ramas. Se revisaron lib, supabase y docs;
no se realizaron cambios de estos módulos en esta entrega.

## RPBI

No se encontró módulo operativo, tablas/RPC ni pantallas de RPBI en esta rama.
`docs/research/rotativo-2023-requisitos.v1.md` ya registra que no se encontró un
módulo de residuos. Los campos de disposición de una eutanasia y las tareas del
equipo no constituyen una bitácora RPBI. Por tanto falta una primera entrega.

Alcance propuesto para esa entrega, pendiente de definir e implementar:

- Parámetros propios de clínica, con fuente, revisión y vigencia cuando proceda.
- Registro de generación: tipo, cantidad/unidad, fecha, área y responsable.
- Trazabilidad de almacenamiento y entrega/recolección, proveedor y comprobantes.
- Incidencias, correcciones anexas, consulta y exportación.
- Permisos por clínica, historial y pruebas de aislamiento y concurrencia.

No precargar tiempos de almacenamiento, colores, categorías, umbrales ni
obligaciones como verificados sin revisar la fuente y su aplicabilidad a cada
clínica. Una bitácora técnica no certifica cumplimiento normativo por sí sola.

## Personal

La base existe en `existing_operations_m9.sql` y en
`lib/modules/operations/presentation/operations_screen.dart`:

- Ficha con grupo sanguíneo, alergias, antecedentes, vacunas y contacto de emergencia.
- Escritura y retirada de la ficha propia mediante ops_medical.
- Consulta propia o por administrador de la misma clínica; tabla con RLS.
- Fecha de consentimiento y actualización; auditoría de modificación sin contenido.
- Exclusiones documentadas de los respaldos de otros empleados.

Pendientes concretos verificados o por cerrar:

1. **Retirada independiente:** la UI exige consent=true antes de atender erase;
   el RPC también pide p_consent=true para borrar. Separar retirada y aceptación
   para que retirar no obligue a consentir de nuevo.
2. **Consentimiento trazable:** hoy no se vincula una versión de aviso/finalidad
   a cada aceptación/retirada. Definir y registrar ese contrato, sin aceptación
   precargada ni sustitución por firma de otra persona.
3. **Consulta administrativa explícita:** el RPC devuelve todas las fichas al
   admin y la UI puede mostrarlas al terminar la edición propia. Separar el
   acceso a la ficha propia de la consulta del equipo; revisar permisos de esa
   consulta y registrar accesos sin copiar el contenido sensible al log.
4. **Privacidad y pruebas:** comprobar cambio de usuario/clínica, retirada,
   salida del integrante, revocación, errores de red, respaldos y retención.
   Existen pruebas base de privacidad de M9; falta validar el flujo completo en
   la instalación y APK finales. No afirmar que esos controles ya están ausentes
   o completos solo por esta revisión estática.

Siguiente tarea recomendada para personal: corregir la retirada y separar la
consulta propia/administrativa, con pruebas de servidor e interfaz. RPBI es un
frente de implementación posterior; no está bloqueado por la investigación de
dosis, aunque sus parámetros normativos necesitan fuentes propias.
