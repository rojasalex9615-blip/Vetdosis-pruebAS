-- 15K · Ingesta verbatim de constantes.p60.v1.csv (16 filas) en el staging ya existente.
-- NO toca catalogos de calculo ni tablas que lee la app. Todo entra en revision ('pending').
--
-- Verificado contra el proyecto Pruebas (wtrelwtztkddfktrfdpb) el 2026-11-08, antes de escribir esto:
--   * raw_intake_rows no contiene ninguna fila de este archivo: 0 coincidencias de
--     'rotativo-p60' y 0 de 'cuadro 12' sobre las 1.087 filas existentes.
--   * Los otros 6 CSV de la misma subida YA estaban cargados via
--     VetDosis_auditoria_consolidada_lotes_1_a_7.xlsx y se compararon celda por celda
--     contra la BD: 181 filas, 0 discrepancias. No se reingestan aqui.
--   * Las 6 hojas de VetDosis_ampliacion_farmacologia_anestesia_lote3.xlsx tambien estan
--     ya cargadas como los CSV de lote 3 (19+12+4+21+8+11 filas, recuentos y valores iguales).
--
-- El CSV declara estado = 'sin_verificar' e importar_en_app = 'false' en cada fila; se
-- conservan tal cual dentro del payload. Promover a las tablas que la app lee es decision
-- clinica de Ale o de un MVZ, no de esta migracion.
--
-- Revertir:
--   delete from vetdosis_reference_staging.raw_intake_rows where batch_id='9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47';
--   delete from vetdosis_reference_staging.import_batches  where id='9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47';

begin;

insert into vetdosis_reference_staging.import_batches
  (id, batch_key, label, origin_filename, original_sha256, ingestion_notes)
values
  ('9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47',
   'constantes_p60_v1_20261108',
   'Constantes fisiologicas canina y felina · portafolio de rotativo p.60 cuadro 12',
   'constantes.p60.v1.csv',
   '4f3abc9cecddf366184d811124e7c495c35950ee17e0c8fbabfe3f3fc86168a2',
   'Transcripcion visual aportada por la propietaria. Sin verificar. El propio archivo marca contradicciones con la p.40 en vez de ocultarlas; se conservan las columnas fuente/estado/nota intactas porque son lo que alimenta VetReferenceCard.')
on conflict (id) do nothing;

insert into vetdosis_reference_staging.raw_intake_rows
  (batch_id, row_key, source_filename, source_sheet, source_row, source_title,
   original_payload, row_sha256, review_state, ingestion_note)
values
  ('9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47',
   'constantes_p60_v1_20261108:row:2',
   'constantes.p60.v1.csv', 'constantes.p60.v1', 2,
   'Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12',
   '{"condiciones_medicion": "", "cuadro": "12", "edad": "", "especie": "canina", "estado": "sin_verificar", "fuente": "Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12", "fuente_sha256": "1e6ff1734b111506288c9f39897f03d4a949c92ca15139cdfb552433ce01a0e5", "id": "rotativo-p60-canina-frecuencia_respiratoria", "importar_en_app": "false", "max": "30", "max_exclusivo": "", "min": "10", "nota": "Transcripción visual; extremos del rango no especifican inclusividad; edad y condiciones no indicadas.", "pagina_pdf": "60", "parametro": "frecuencia_respiratoria", "unidad": "resp/min", "valor_literal": "10-30", "version": "1"}'::jsonb,
   '4f7a32e08ed73faa731d5d306ccbc6c04e4f18f6b20016e26881abf0869a0167',
   'pending', 'Imported verbatim; not clinically validated'),
  ('9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47',
   'constantes_p60_v1_20261108:row:3',
   'constantes.p60.v1.csv', 'constantes.p60.v1', 3,
   'Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12',
   '{"condiciones_medicion": "", "cuadro": "12", "edad": "", "especie": "felina", "estado": "sin_verificar", "fuente": "Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12", "fuente_sha256": "1e6ff1734b111506288c9f39897f03d4a949c92ca15139cdfb552433ce01a0e5", "id": "rotativo-p60-felina-frecuencia_respiratoria", "importar_en_app": "false", "max": "42", "max_exclusivo": "", "min": "20", "nota": "Transcripción visual; extremos del rango no especifican inclusividad; edad y condiciones no indicadas. Referencia diferente en p.40; no resuelta.", "pagina_pdf": "60", "parametro": "frecuencia_respiratoria", "unidad": "resp/min", "valor_literal": "20-42", "version": "1"}'::jsonb,
   '7621bfc1e0a55c41b5f79f64471d2c308a548cd68cd8fe8932598e4518c2d29f',
   'pending', 'Imported verbatim; not clinically validated'),
  ('9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47',
   'constantes_p60_v1_20261108:row:4',
   'constantes.p60.v1.csv', 'constantes.p60.v1', 4,
   'Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12',
   '{"condiciones_medicion": "", "cuadro": "12", "edad": "", "especie": "canina", "estado": "sin_verificar", "fuente": "Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12", "fuente_sha256": "1e6ff1734b111506288c9f39897f03d4a949c92ca15139cdfb552433ce01a0e5", "id": "rotativo-p60-canina-frecuencia_cardiaca", "importar_en_app": "false", "max": "180", "max_exclusivo": "", "min": "60", "nota": "Transcripción visual; extremos del rango no especifican inclusividad; edad y condiciones no indicadas.", "pagina_pdf": "60", "parametro": "frecuencia_cardiaca", "unidad": "lat/min", "valor_literal": "60-180", "version": "1"}'::jsonb,
   '3d6d16b4fa4be38c46d77b77c41dd94ba43755f1d3d6aab8e7cb16a13ff30803',
   'pending', 'Imported verbatim; not clinically validated'),
  ('9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47',
   'constantes_p60_v1_20261108:row:5',
   'constantes.p60.v1.csv', 'constantes.p60.v1', 5,
   'Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12',
   '{"condiciones_medicion": "", "cuadro": "12", "edad": "", "especie": "felina", "estado": "sin_verificar", "fuente": "Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12", "fuente_sha256": "1e6ff1734b111506288c9f39897f03d4a949c92ca15139cdfb552433ce01a0e5", "id": "rotativo-p60-felina-frecuencia_cardiaca", "importar_en_app": "false", "max": "220", "max_exclusivo": "", "min": "140", "nota": "Transcripción visual; extremos del rango no especifican inclusividad; edad y condiciones no indicadas. Referencia diferente en p.40; no resuelta.", "pagina_pdf": "60", "parametro": "frecuencia_cardiaca", "unidad": "lat/min", "valor_literal": "140-220", "version": "1"}'::jsonb,
   '3d6ebddd5aaef5c6900f6ead3540eb6503dbe18b9c44c9c405ae1533c7f4a0c8',
   'pending', 'Imported verbatim; not clinically validated'),
  ('9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47',
   'constantes_p60_v1_20261108:row:6',
   'constantes.p60.v1.csv', 'constantes.p60.v1', 6,
   'Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12',
   '{"condiciones_medicion": "", "cuadro": "12", "edad": "", "especie": "canina", "estado": "sin_verificar", "fuente": "Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12", "fuente_sha256": "1e6ff1734b111506288c9f39897f03d4a949c92ca15139cdfb552433ce01a0e5", "id": "rotativo-p60-canina-tiempo_relleno_capilar", "importar_en_app": "false", "max": "2", "max_exclusivo": "true", "min": "", "nota": "Límite superior estricto literal; sin límite inferior aportado. Contradicción con referencia felina de p.40.", "pagina_pdf": "60", "parametro": "tiempo_relleno_capilar", "unidad": "s", "valor_literal": "< 2", "version": "1"}'::jsonb,
   '252ab70a0670b90385b90317c5960b7531222a567c887be15d7c9835def275be',
   'pending', 'Imported verbatim; not clinically validated'),
  ('9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47',
   'constantes_p60_v1_20261108:row:7',
   'constantes.p60.v1.csv', 'constantes.p60.v1', 7,
   'Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12',
   '{"condiciones_medicion": "", "cuadro": "12", "edad": "", "especie": "felina", "estado": "sin_verificar", "fuente": "Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12", "fuente_sha256": "1e6ff1734b111506288c9f39897f03d4a949c92ca15139cdfb552433ce01a0e5", "id": "rotativo-p60-felina-tiempo_relleno_capilar", "importar_en_app": "false", "max": "2", "max_exclusivo": "true", "min": "", "nota": "Límite superior estricto literal; sin límite inferior aportado. Contradicción con referencia felina de p.40.", "pagina_pdf": "60", "parametro": "tiempo_relleno_capilar", "unidad": "s", "valor_literal": "< 2", "version": "1"}'::jsonb,
   '5976592cbf1b3c7967ecafc98d2ad2254b474c86ccb86396fef117e429a8720b',
   'pending', 'Imported verbatim; not clinically validated'),
  ('9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47',
   'constantes_p60_v1_20261108:row:8',
   'constantes.p60.v1.csv', 'constantes.p60.v1', 8,
   'Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12',
   '{"condiciones_medicion": "", "cuadro": "12", "edad": "", "especie": "canina", "estado": "sin_verificar", "fuente": "Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12", "fuente_sha256": "1e6ff1734b111506288c9f39897f03d4a949c92ca15139cdfb552433ce01a0e5", "id": "rotativo-p60-canina-temperatura_corporal", "importar_en_app": "false", "max": "39.2", "max_exclusivo": "", "min": "37.5", "nota": "Transcripción visual; extremos del rango no especifican inclusividad; edad y condiciones no indicadas.", "pagina_pdf": "60", "parametro": "temperatura_corporal", "unidad": "°C", "valor_literal": "37,5-39,2", "version": "1"}'::jsonb,
   '9bbb48d5d55da8371c906e83d13033145c6d97797507aa378608e646bff53dc1',
   'pending', 'Imported verbatim; not clinically validated'),
  ('9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47',
   'constantes_p60_v1_20261108:row:9',
   'constantes.p60.v1.csv', 'constantes.p60.v1', 9,
   'Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12',
   '{"condiciones_medicion": "", "cuadro": "12", "edad": "", "especie": "felina", "estado": "sin_verificar", "fuente": "Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12", "fuente_sha256": "1e6ff1734b111506288c9f39897f03d4a949c92ca15139cdfb552433ce01a0e5", "id": "rotativo-p60-felina-temperatura_corporal", "importar_en_app": "false", "max": "39.2", "max_exclusivo": "", "min": "38", "nota": "Transcripción visual; extremos del rango no especifican inclusividad; edad y condiciones no indicadas. Referencia diferente en p.40; no resuelta.", "pagina_pdf": "60", "parametro": "temperatura_corporal", "unidad": "°C", "valor_literal": "38-39,2", "version": "1"}'::jsonb,
   '023692cb99068544f00a3e2419fac90b28f84a1fda862ef24c5b42f67a0e7074',
   'pending', 'Imported verbatim; not clinically validated'),
  ('9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47',
   'constantes_p60_v1_20261108:row:10',
   'constantes.p60.v1.csv', 'constantes.p60.v1', 10,
   'Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12',
   '{"condiciones_medicion": "", "cuadro": "12", "edad": "", "especie": "canina", "estado": "sin_verificar", "fuente": "Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12", "fuente_sha256": "1e6ff1734b111506288c9f39897f03d4a949c92ca15139cdfb552433ce01a0e5", "id": "rotativo-p60-canina-presion_arterial_sistolica", "importar_en_app": "false", "max": "160", "max_exclusivo": "", "min": "100", "nota": "Transcripción visual; extremos del rango no especifican inclusividad; edad y condiciones no indicadas.", "pagina_pdf": "60", "parametro": "presion_arterial_sistolica", "unidad": "mmHg", "valor_literal": "100-160", "version": "1"}'::jsonb,
   '74796c014d003793270d3a2251ce9bdc91de5318e8f5b6df60b8fe67840485c8',
   'pending', 'Imported verbatim; not clinically validated'),
  ('9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47',
   'constantes_p60_v1_20261108:row:11',
   'constantes.p60.v1.csv', 'constantes.p60.v1', 11,
   'Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12',
   '{"condiciones_medicion": "", "cuadro": "12", "edad": "", "especie": "felina", "estado": "sin_verificar", "fuente": "Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12", "fuente_sha256": "1e6ff1734b111506288c9f39897f03d4a949c92ca15139cdfb552433ce01a0e5", "id": "rotativo-p60-felina-presion_arterial_sistolica", "importar_en_app": "false", "max": "180", "max_exclusivo": "", "min": "120", "nota": "Transcripción visual; extremos del rango no especifican inclusividad; edad y condiciones no indicadas.", "pagina_pdf": "60", "parametro": "presion_arterial_sistolica", "unidad": "mmHg", "valor_literal": "120-180", "version": "1"}'::jsonb,
   '0740ce1f1dd05be4706683304df6c4e485e69db4b4eaa44b88bb1b444dab4fb0',
   'pending', 'Imported verbatim; not clinically validated'),
  ('9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47',
   'constantes_p60_v1_20261108:row:12',
   'constantes.p60.v1.csv', 'constantes.p60.v1', 12,
   'Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12',
   '{"condiciones_medicion": "", "cuadro": "12", "edad": "", "especie": "canina", "estado": "sin_verificar", "fuente": "Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12", "fuente_sha256": "1e6ff1734b111506288c9f39897f03d4a949c92ca15139cdfb552433ce01a0e5", "id": "rotativo-p60-canina-presion_arterial_media", "importar_en_app": "false", "max": "120", "max_exclusivo": "", "min": "80", "nota": "Transcripción visual; extremos del rango no especifican inclusividad; edad y condiciones no indicadas. La fuente imprime PAM=[(PAS-PAD)/3]+PAD; fórmula no implementada ni validada en esta revisión.", "pagina_pdf": "60", "parametro": "presion_arterial_media", "unidad": "mmHg", "valor_literal": "80-120", "version": "1"}'::jsonb,
   'c49dd3815cd06f3575ff70a5962820beac497898b26d028b85af3d2f6fd5ee96',
   'pending', 'Imported verbatim; not clinically validated'),
  ('9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47',
   'constantes_p60_v1_20261108:row:13',
   'constantes.p60.v1.csv', 'constantes.p60.v1', 13,
   'Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12',
   '{"condiciones_medicion": "", "cuadro": "12", "edad": "", "especie": "felina", "estado": "sin_verificar", "fuente": "Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12", "fuente_sha256": "1e6ff1734b111506288c9f39897f03d4a949c92ca15139cdfb552433ce01a0e5", "id": "rotativo-p60-felina-presion_arterial_media", "importar_en_app": "false", "max": "150", "max_exclusivo": "", "min": "100", "nota": "Transcripción visual; extremos del rango no especifican inclusividad; edad y condiciones no indicadas. La fuente imprime PAM=[(PAS-PAD)/3]+PAD; fórmula no implementada ni validada en esta revisión.", "pagina_pdf": "60", "parametro": "presion_arterial_media", "unidad": "mmHg", "valor_literal": "100-150", "version": "1"}'::jsonb,
   '6dee22dcde0cd50133b3d5ef0354919b1fb0608f3d716cbe83b86586dc1324d1',
   'pending', 'Imported verbatim; not clinically validated'),
  ('9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47',
   'constantes_p60_v1_20261108:row:14',
   'constantes.p60.v1.csv', 'constantes.p60.v1', 14,
   'Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12',
   '{"condiciones_medicion": "", "cuadro": "12", "edad": "", "especie": "canina", "estado": "sin_verificar", "fuente": "Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12", "fuente_sha256": "1e6ff1734b111506288c9f39897f03d4a949c92ca15139cdfb552433ce01a0e5", "id": "rotativo-p60-canina-presion_arterial_diastolica", "importar_en_app": "false", "max": "90", "max_exclusivo": "", "min": "60", "nota": "Transcripción visual; extremos del rango no especifican inclusividad; edad y condiciones no indicadas.", "pagina_pdf": "60", "parametro": "presion_arterial_diastolica", "unidad": "mmHg", "valor_literal": "60-90", "version": "1"}'::jsonb,
   'b8308430744a858703f065b70717daac3e84b5f9eb68ce5185eb44b853d9bb98',
   'pending', 'Imported verbatim; not clinically validated'),
  ('9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47',
   'constantes_p60_v1_20261108:row:15',
   'constantes.p60.v1.csv', 'constantes.p60.v1', 15,
   'Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12',
   '{"condiciones_medicion": "", "cuadro": "12", "edad": "", "especie": "felina", "estado": "sin_verificar", "fuente": "Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12", "fuente_sha256": "1e6ff1734b111506288c9f39897f03d4a949c92ca15139cdfb552433ce01a0e5", "id": "rotativo-p60-felina-presion_arterial_diastolica", "importar_en_app": "false", "max": "100", "max_exclusivo": "", "min": "60", "nota": "Transcripción visual; extremos del rango no especifican inclusividad; edad y condiciones no indicadas.", "pagina_pdf": "60", "parametro": "presion_arterial_diastolica", "unidad": "mmHg", "valor_literal": "60-100", "version": "1"}'::jsonb,
   'b6277e3829ae9d317e98dfb5fe0b034cc48a75340d9b467e8ff1caf09da4a8c0',
   'pending', 'Imported verbatim; not clinically validated'),
  ('9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47',
   'constantes_p60_v1_20261108:row:16',
   'constantes.p60.v1.csv', 'constantes.p60.v1', 16,
   'Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12',
   '{"condiciones_medicion": "", "cuadro": "12", "edad": "", "especie": "canina", "estado": "sin_verificar", "fuente": "Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12", "fuente_sha256": "1e6ff1734b111506288c9f39897f03d4a949c92ca15139cdfb552433ce01a0e5", "id": "rotativo-p60-canina-produccion_orina", "importar_en_app": "false", "max": "2", "max_exclusivo": "", "min": "1", "nota": "Transcripción visual; extremos del rango no especifican inclusividad; edad y condiciones no indicadas.", "pagina_pdf": "60", "parametro": "produccion_orina", "unidad": "ml/kg/h", "valor_literal": "1-2", "version": "1"}'::jsonb,
   'e48ffd044c4368c1741b69fce938d3de31baa95ce513a4b8df9d922b1b105f08',
   'pending', 'Imported verbatim; not clinically validated'),
  ('9f3c1d84-7b25-4a6e-93cf-2d0fb8e51a47',
   'constantes_p60_v1_20261108:row:17',
   'constantes.p60.v1.csv', 'constantes.p60.v1', 17,
   'Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12',
   '{"condiciones_medicion": "", "cuadro": "12", "edad": "", "especie": "felina", "estado": "sin_verificar", "fuente": "Portafolio de rotativo aportado por la propietaria; p.60, cuadro 12", "fuente_sha256": "1e6ff1734b111506288c9f39897f03d4a949c92ca15139cdfb552433ce01a0e5", "id": "rotativo-p60-felina-produccion_orina", "importar_en_app": "false", "max": "2", "max_exclusivo": "", "min": "1", "nota": "Transcripción visual; extremos del rango no especifican inclusividad; edad y condiciones no indicadas.", "pagina_pdf": "60", "parametro": "produccion_orina", "unidad": "ml/kg/h", "valor_literal": "1-2", "version": "1"}'::jsonb,
   '05fe4b1d6c7a4dec1786e9018cca0552e03e6d54eb6889da292b5ff5633983f1',
   'pending', 'Imported verbatim; not clinically validated')
on conflict (batch_id, row_key) do nothing;

commit;
