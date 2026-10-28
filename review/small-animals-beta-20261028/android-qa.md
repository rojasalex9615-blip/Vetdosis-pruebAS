# QA pendiente — beta Pequeñas especies

No hay casillas aprobadas por adelantado. Usar exclusivamente datos ficticios. Registrar cada paso con resultado, hora, usuario/rol sintético, clínica, pantalla/error y evidencia sin claves ni información real.

## Identificación obligatoria del artefacto

| Campo | Por completar al compilar |
|---|---|
| Repositorio y rama | `Vetdosis-pruebAS` / `integration/pequenas-beta-validation-20261028` |
| SHA completo construido | Pendiente; debe incluir las correcciones revisadas |
| APK / SHA-256 | Pendiente |
| Package ID / flavor / versionCode / certificado | Pendiente |
| Proyecto backend y versión de contratos | Pruebas; verificar orden de despliegue autorizado |
| Android / modelo / fabricante / batería | Pendiente |
| Responsable / fecha | Pendiente |

Preparar clínicas ficticias A y B con una cuenta de prueba con membresía en ambas y roles diferentes. Añadir una cuenta que solo pertenezca a B y un usuario con lectura sin escritura. Conservar configuración inicial y evitar envíos a teléfonos reales ajenos al ensayo.

## Recorrido clínico de aceptación

| Paso | Acción | Criterio observable | Estado |
|---|---|---|---|
| 1 | En A, crear tutor/paciente y cita de consulta | Una identidad enlazada, sin duplicación ni pedir repetir datos ya guardados | Pendiente |
| 2 | Abrir paciente desde Agenda | Mismo patient_id y clínica; historial coherente, acceso según permiso | Pendiente |
| 3 | Iniciar consulta y capturar solo datos disponibles | No inventa peso/temperatura/SOAP ni asigna firma ajena; guarda responsable autorizado | Pendiente |
| 4 | Registrar peso y abrir cálculo | Muestra peso, fecha y origen; usuario elige fármaco/presentación/especie/vía | Pendiente |
| 5 | Confirmar cálculo conocido: 12.5 kg × 2 mg/kg ÷ 25 mg/mL | 1 mL; son datos aritméticos ficticios, no pauta terapéutica. Cambiar entradas invalida resultado | Pendiente |
| 6 | Preparar receta para el caso correcto | Datos y unidades revisados; no presupone creación automática desde cálculo | Pendiente |
| 7 | Autorizar y generar PDF | Solo profesional habilitado, firma propia y versión correcta; folio capturado; descarga autorizada | Pendiente |
| 8 | Admitir/abrir hospitalización del mismo paciente | Caso y paciente correctos; indicaciones confirmadas, sin órdenes ficticias automáticas | Pendiente |
| 9 | Aplicar, posponer o no aplicar una indicación | Cada estado conserva su significado; doble toque/reintento no duplica administración ni inventario | Pendiente |
| 10 | Volver a expediente y dar cierre autorizado | Receta, eventos, consumo e historial coherentes; revocaciones respetadas | Pendiente |

## Finanzas, inventario y trazabilidad

| Caso | Criterio observable | Estado |
|---|---|---|
| Venta pagada y crédito con dos abonos idénticos legítimos | Se registran ambos abonos nuevos; reintentar uno tras respuesta perdida no duplica | Pendiente |
| Producto no farmacológico, tres devoluciones de un tercio | Cantidad/costo/restock/redondeo acumulado y saldo coinciden con el original | Pendiente |
| Venta mixta producto/servicio | Privilegios de servicio/admin y producto se separan; no devuelve fármacos por ruta general | Pendiente |
| Comisión devengada, liquidada, reversada y reintegrada | No confundir venta neta con efectivo; reintegro requiere recepción confirmada y no supera lo debido | Pendiente |
| Corte de caja y reintento histórico | Corte cerrado conserva cifras congeladas; recibo reintentado mantiene identidad | Pendiente |
| Dos personas cobran/devuelven simultáneamente | Saldos y cantidades no sobrepasan venta; formulario obsoleto exige recarga | Pendiente |
| Frasco con movimiento tardío/incidencia | Reporta incidente autorizado; conciliación no duplica ni oculta historia | Pendiente |

## Aislamiento y permisos

| Caso | Criterio observable | Estado |
|---|---|---|
| Cambiar A → B con solicitudes en vuelo | Respuesta de A no aparece ni se escribe bajo B; selector no retrocede por una recarga tardía | Pendiente |
| Rol distinto en B | Reobtiene permisos/preferencias; ser admin visual no concede autoridad clínica | Pendiente |
| Quitar membresía o permiso de procedimiento | Formulario abierto pierde capacidad; llamada directa RPC también rechaza | Pendiente |
| Intentar ID/archivo/PDF de A desde usuario solo de B | Sin datos de A, sin URL firmada nueva, RPC/Storage rechazan | Pendiente |
| Cambiar cuenta, cerrar sesión y reconectar | Limpia datos visibles y destinatarios propios; no reutiliza caché/acciones de otra identidad | Pendiente |
| Ocultar módulos/tarjetas | No borra datos ni cancela avisos críticos por una preferencia visual | Pendiente |
| Avión/corte de red durante escritura | Explica indisponibilidad y conserva reintento seguro; no promete captura clínica offline no implementada | Pendiente |

## Archivos, respaldo y avisos reales

| Caso | Criterio observable | Estado |
|---|---|---|
| Foto/adjunto y archivo de clínica ajena | Autoriza cada operación; tipos/tamaño correctos; no cruza clínicas | Pendiente |
| PDF generado, compartido e impreso | Firma, Unicode, saltos/paginación e identidad correctos; funciones nativas sin crash | Pendiente |
| Drive OAuth por clínica, copia cifrada y verificación | Consentimiento explícito; descargar y comparar hash antes de «verificado» | Pendiente |
| Recuperación integral desde copia externa | En entorno aislado, comprobar PostgreSQL y bytes Storage concordantes; no basta abrir el ZIP | Pendiente |
| Alarmas locales con app cerrada, bloqueada y tras reiniciar | Horario/zona/permisos/batería correctos; al tocar, exige sesión y clínica vigentes | Pendiente |
| FCM real y cambio de token/cuenta/clínica | Enrolamiento consentido, revocación efectiva y sin datos clínicos sensibles en payload | Pendiente |
| WhatsApp, si se incluye y está autorizado | Destinatario ficticio controlado y recepción acreditada; estado enviado no se infiere de cola | Pendiente |
| Fabricante/API indisponible | Estado real de entrega; conserva fallback local y no anuncia éxito inexistente | Pendiente |

## Decisión

Mantener NO DISTRIBUIR mientras haya error de permisos/aislamiento, pérdida/duplicación financiera, firma incorrecta, contrato faltante o pasos críticos sin evidencia. Diferenciar un defecto de una función excluida: si Drive/WhatsApp/producción/RPBI no entran en el alcance beta, declararlo en interfaz/alcance revisado antes de validar distribución.

Claude puede organizar coherencia y dependencias; cada resultado de QA requiere evidencia de quien realmente lo ejecute. Una revisión de código o un build exitoso no marca estos casos como aprobados.
