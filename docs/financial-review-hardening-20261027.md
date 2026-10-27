# Correcciones de revisión financiera

Candidata sobre #50; responde a los informes #44, #45 y #46. No aplicada remotamente.

- Abonos: un éxito confirmado descarta el identificador de reintento; dos pagos legítimos idénticos crean operaciones distintas. Una respuesta perdida conserva su recibo.
- Comisiones: una respuesta de otra clínica no borra el recibo pendiente del ámbito actual. Servicios completamente revertidos dejan de aparecer como comisión a la espera de cobro.
- Devolución v3: exige cantidad acumulada previamente devuelta, comprobada bajo bloqueo. Cambiar motivo o medio tras una respuesta perdida no permite repetir el reembolso desde el mismo estado. Los contratos antiguos solo reproducen recibos ya confirmados; las escrituras nuevas requieren actualización.
- Ventas que incluyen servicios requieren administración y permiso service.manage para consultar o devolver cualquiera de sus líneas. Evita entregar comisiones al personal sin autorización. Esta restricción también afecta una línea de producto dentro de una venta mixta.
- Reposición: valida producto y lote original y usa el costo unitario del lote cuando falta el metadato histórico. No fabrica un lote para ventas sin lote.
- Corte cerrado: mantiene su contenido financiero congelado y saneado; las acciones disponibles se consultan por separado, sin importes actuales. CSV de devoluciones incluye costo recuperado.

Validación: pruebas PostgreSQL sintéticas sin red, reproducción de recibos v1/v2, estado obsoleto, redondeo acumulado 0.34/0.33/0.33, congelación de respuesta y carreras de cobro/devolución; pruebas Flutter de respuesta perdida y dos abonos idénticos legítimos. El despliegue requiere publicar juntos servidor y cliente; cliente antiguo no admite nuevas devoluciones. No equivale a QA real ni a revisión final favorable.
