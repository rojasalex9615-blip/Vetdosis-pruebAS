-- Biblioteca de referencias sintetica. Reproduce la FORMA del esquema de
-- preparacion que ya existe en el servidor (vetdosis_reference_staging) para
-- poder probar 15N sin tocarlo.
--
-- LOS VALORES SON INVENTADOS Y LA ESPECIE NO EXISTE. La especie es
-- 'synthetic', la misma del fixture de pacientes, y las fuentes se llaman
-- «Fuente ...». Nada de aqui es una referencia clinica ni debe copiarse a
-- ningun entorno real.
create schema if not exists vetdosis_reference_staging;
create table vetdosis_reference_staging.raw_intake_rows(
 id uuid primary key default gen_random_uuid(),
 batch_id uuid not null default gen_random_uuid(),
 row_key text not null,
 source_filename text not null,
 source_sheet text not null,
 source_row integer not null,
 source_title text,
 original_payload jsonb not null,
 row_sha256 text not null,
 review_state text not null default 'pending',
 ingestion_note text not null default 'Imported verbatim; not clinically validated',
 recorded_at timestamptz not null default now()
);
revoke all on vetdosis_reference_staging.raw_intake_rows from public,anon,authenticated;

insert into vetdosis_reference_staging.raw_intake_rows
 (row_key,source_filename,source_sheet,source_row,original_payload,row_sha256)
values
 -- Dos fuentes para el mismo analito y unidad: el caso que manda.
 ('s1','sintetico.csv','hoja',1,jsonb_build_object('Categoría','Hematología','Especie','synthetic',
   'Parámetro','eritrocitos','Mín.','5.5','Máx.','8.5','Unidad original','10^6/uL','Fuente','Fuente biblioteca A','Otro intervalo','No'),'h1'),
 ('s2','sintetico.csv','hoja',2,jsonb_build_object('Categoría','Hematología','Especie','synthetic',
   'Parámetro','eritrocitos','Mín.','6.0','Máx.','9.0','Unidad original','10^6/uL','Fuente','Fuente biblioteca B','Otro intervalo','No'),'h2'),
 -- El archivo avisa de otro intervalo sin darlo: el aviso viaja, el rango no se inventa.
 ('s3','sintetico.csv','hoja',3,jsonb_build_object('Categoría','Bioquímica','Especie','synthetic',
   'Parámetro','glucosa','Mín.','70','Máx.','105','Unidad original','mg/dL','Fuente','Fuente biblioteca C','Otro intervalo','Sí'),'h3'),
 -- Unidad distinta de la capturada: debe llegar y marcarse, no desaparecer.
 ('s4','sintetico.csv','hoja',4,jsonb_build_object('Categoría','Bioquímica','Especie','synthetic',
   'Parámetro','urea','Mín.','3.5','Máx.','9.0','Unidad original','mmol/L','Fuente','Fuente biblioteca D','Otro intervalo','No'),'h4'),
 -- Filas que NO son un rango: sin unidad, con limite no numerico, invertida,
 -- sin fuente y de una categoria que no es de laboratorio.
 ('s5','sintetico.csv','hoja',5,jsonb_build_object('Categoría','Bioquímica','Especie','synthetic',
   'Parámetro','indice sin unidad','Mín.','0.2','Máx.','0.4','Unidad original','(NULL)','Fuente','Fuente biblioteca E','Otro intervalo','No'),'h5'),
 ('s6','sintetico.csv','hoja',6,jsonb_build_object('Categoría','Bioquímica','Especie','synthetic',
   'Parámetro','texto','Mín.','menos de 1','Máx.','2','Unidad original','mg/dL','Fuente','Fuente biblioteca F','Otro intervalo','No'),'h6'),
 ('s7','sintetico.csv','hoja',7,jsonb_build_object('Categoría','Bioquímica','Especie','synthetic',
   'Parámetro','invertida','Mín.','9','Máx.','2','Unidad original','mg/dL','Fuente','Fuente biblioteca G','Otro intervalo','No'),'h7'),
 ('s8','sintetico.csv','hoja',8,jsonb_build_object('Categoría','Bioquímica','Especie','synthetic',
   'Parámetro','sin fuente','Mín.','1','Máx.','2','Unidad original','mg/dL','Fuente','  ','Otro intervalo','No'),'h8'),
 ('s9','sintetico.csv','hoja',9,jsonb_build_object('Categoría','Constantes','Especie','synthetic',
   'Parámetro','eritrocitos','Mín.','1','Máx.','2','Unidad original','10^6/uL','Fuente','Fuente de fisiologia','Otro intervalo','No'),'h9'),
 -- Otra especie: no debe cruzarse.
 ('s10','sintetico.csv','hoja',10,jsonb_build_object('Categoría','Hematología','Especie','otra especie sintetica',
   'Parámetro','eritrocitos','Mín.','1','Máx.','2','Unidad original','10^6/uL','Fuente','Fuente biblioteca H','Otro intervalo','No'),'h10');
