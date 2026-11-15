-- 15S: catalogo de dictamenes ambientales (SEMARNAT) para porcinos, por estado.
-- Origen: VetDosis_Dictamen_Ambiental_Yucatan_SEMARNAT.csv.
-- El catalogo es extensible: la clave es (estado, id) para poder sumar los
-- dictamenes de otros estados sin colision de ids. Hoy solo trae Yucatan.
-- Catalogo de solo lectura para autenticados: mismas reglas que
-- produccion_bioseguridad_refs de 20261114000200_produccion_bioseguridad_refs.sql.
--
-- ESTADO: CANDIDATO. No aplicado en Supabase Pruebas: el panel de la app lee
-- estos valores del dominio Dart (lib/modules/production/domain/porcino_environment.dart),
-- asi que no depende de esta tabla. Aplicar cuando se quiera servir el catalogo
-- desde la base (psql/DB URL o el editor SQL).
begin;

create table if not exists public.produccion_ambiental_refs (
  estado text not null check (char_length(btrim(estado)) between 3 and 40),
  id text not null check (id ~ '^[a-z][a-z0-9_]{2,59}$'),
  categoria text not null check (char_length(btrim(categoria)) between 3 and 80),
  dato text not null check (char_length(btrim(dato)) between 1 and 120),
  valor text not null default '' check (char_length(valor) <= 200),
  unidad text not null default '' check (char_length(unidad) <= 24),
  nota text not null default '' check (char_length(nota) <= 600),
  fuente text not null check (char_length(btrim(fuente)) between 3 and 200),
  pagina_o_seccion text not null default '' check (char_length(pagina_o_seccion) <= 200),
  orden integer not null default 0,
  created_at timestamptz not null default now(),
  primary key (estado, id)
);

create index if not exists produccion_ambiental_refs_estado_categoria
  on public.produccion_ambiental_refs(estado, categoria, orden, dato);

alter table public.produccion_ambiental_refs enable row level security;
revoke all on public.produccion_ambiental_refs from public,anon,authenticated;
grant select on public.produccion_ambiental_refs to authenticated;

drop policy if exists produccion_ambiental_refs_read on public.produccion_ambiental_refs;
create policy produccion_ambiental_refs_read on public.produccion_ambiental_refs
  for select to authenticated using (auth.uid() is not null);

insert into public.produccion_ambiental_refs(estado,id,categoria,dato,valor,unidad,nota,fuente,pagina_o_seccion,orden) values
 ('Yucatan','ecuacion_hhgris','Ecuaciones','Huella hidrica gris','HHGris = Carga / (Cmax - Cnat)','','Mekonnen y Hoekstra (2016)','Dictamen Diagnostico Ambiental de la Actividad Porcicola en Yucatan (SEMARNAT, marzo 2023)','84',1),
 ('Yucatan','ecuacion_nca','Ecuaciones','Nivel de contaminacion del agua','NCA = HHGris / Recarga unitaria','','Si NCA > 1, condicion de no sustentabilidad','Dictamen Diagnostico Ambiental de la Actividad Porcicola en Yucatan (SEMARNAT, marzo 2023)','84',2),
 ('Yucatan','carga_nitrogeno_por_cerdo','Parametros NCA','Carga de nitrogeno por cerdo','18','kg N/cerdo/anio','Segun DEFRA (2007)','Dictamen Diagnostico Ambiental de la Actividad Porcicola en Yucatan (SEMARNAT, marzo 2023)','84',1),
 ('Yucatan','cnat_nitrogeno','Parametros NCA','Concentracion natural de N en el acuifero','1.5','mg/L','Muestreo en 20 cenotes de zonas con baja presencia humana','Dictamen Diagnostico Ambiental de la Actividad Porcicola en Yucatan (SEMARNAT, marzo 2023)','84',2),
 ('Yucatan','cmax_propuesto_doble_natural','Parametros NCA','Cmax propuesto (doble de la natural)','3.0','mg/L','Doble de la concentracion natural definida en el estudio','Dictamen Diagnostico Ambiental de la Actividad Porcicola en Yucatan (SEMARNAT, marzo 2023)','84-85',3),
 ('Yucatan','cmax_ajustado_otras_fuentes','Parametros NCA','Cmax ajustado por otras fuentes','10.0','mg/L','Tres veces por encima del propuesto por Liu et al. 2012; considera otras fuentes (avicolas y demas)','Dictamen Diagnostico Ambiental de la Actividad Porcicola en Yucatan (SEMARNAT, marzo 2023)','86',4),
 ('Yucatan','recarga_anual_acuifero','Parametros NCA','Recarga anual del acuifero','21813','Hm3/anio','Datos oficiales','Dictamen Diagnostico Ambiental de la Actividad Porcicola en Yucatan (SEMARNAT, marzo 2023)','84',5),
 ('Yucatan','superficie_acuifero','Parametros NCA','Superficie del acuifero','124409','km2','','Dictamen Diagnostico Ambiental de la Actividad Porcicola en Yucatan (SEMARNAT, marzo 2023)','84',6),
 ('Yucatan','recarga_unitaria','Parametros NCA','Recarga unitaria','175336','m3/km2','Recarga anual / superficie = 21 813 Hm3/anio / 124 409 km2','Dictamen Diagnostico Ambiental de la Actividad Porcicola en Yucatan (SEMARNAT, marzo 2023)','84',7),
 ('Yucatan','interpretacion_nca_mayor_1','Interpretacion','NCA > 1','','','Condicion de no sustentabilidad: se rebasa la capacidad de renovacion del agua','Dictamen Diagnostico Ambiental de la Actividad Porcicola en Yucatan (SEMARNAT, marzo 2023)','84',1),
 ('Yucatan','interpretacion_nca_mayor_2','Interpretacion','NCA > 2','','','Condiciones criticas para la sustentabilidad hidrica','Dictamen Diagnostico Ambiental de la Actividad Porcicola en Yucatan (SEMARNAT, marzo 2023)','85',2),
 ('Yucatan','municipios_nca_mayor_2_cmax3','Resultados con Cmax = 3.0','Municipios con NCA > 2','26','municipios','De 51 municipios con actividad porcicola','Dictamen Diagnostico Ambiental de la Actividad Porcicola en Yucatan (SEMARNAT, marzo 2023)','85',1),
 ('Yucatan','municipios_nca_entre_1_y_2_cmax3','Resultados con Cmax = 3.0','Municipios con NCA entre 1 y 2','4','municipios','Condiciones urgentes de atencion','Dictamen Diagnostico Ambiental de la Actividad Porcicola en Yucatan (SEMARNAT, marzo 2023)','85',2),
 ('Yucatan','municipios_nca_menor_1_cmax3','Resultados con Cmax = 3.0','Municipios con NCA < 1','21','municipios','Rango sustentable','Dictamen Diagnostico Ambiental de la Actividad Porcicola en Yucatan (SEMARNAT, marzo 2023)','85',3)
on conflict (estado,id) do nothing;

notify pgrst,'reload schema';
commit;
