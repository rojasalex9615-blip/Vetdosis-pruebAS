-- 15Q: catalogo de referencias de bioseguridad porcina (Pork School ago-2026).
-- Origen: VetDosis_Bioseguridad_PorkSchool.csv (Jean Paul Cano).
-- Catalogo de solo lectura para autenticados: mismas reglas que
-- produccion_especies/produccion_metricas de 20261112000100_produccion_lotes.sql.
--
-- ESTADO: APLICADO en Supabase Pruebas el 2026-11-14 (autorizado por Ale).
begin;

create table if not exists public.produccion_bioseguridad_refs (
  id text primary key check (id ~ '^[a-z][a-z0-9_]{2,59}$'),
  categoria text not null check (char_length(btrim(categoria)) between 3 and 80),
  dato text not null check (char_length(btrim(dato)) between 1 and 120),
  valor text not null default '' check (char_length(valor) <= 200),
  unidad text not null default '' check (char_length(unidad) <= 24),
  nota text not null default '' check (char_length(nota) <= 600),
  confianza text not null check (confianza in ('alta','media','baja')),
  fuente text not null check (char_length(btrim(fuente)) between 3 and 200),
  pagina_o_seccion text not null default '' check (char_length(pagina_o_seccion) <= 200),
  orden integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists produccion_bioseguridad_refs_categoria
  on public.produccion_bioseguridad_refs(categoria, orden, dato);

alter table public.produccion_bioseguridad_refs enable row level security;
revoke all on public.produccion_bioseguridad_refs from public,anon,authenticated;
grant select on public.produccion_bioseguridad_refs to authenticated;

drop policy if exists produccion_bioseguridad_refs_read on public.produccion_bioseguridad_refs;
create policy produccion_bioseguridad_refs_read on public.produccion_bioseguridad_refs
  for select to authenticated using (auth.uid() is not null);

insert into public.produccion_bioseguridad_refs(id,categoria,dato,valor,unidad,nota,confianza,fuente,pagina_o_seccion,orden) values
 ('distancia_mismo_sitio_alto_riesgo','Distancias entre granjas','Mismo sitio o granja contigua','< 0.5','km','Mismo sitio o granja por alto riesgo de transmision (roedores, insectos, polvo, personas)','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Diapositiva Distancia',1),
 ('distancia_riesgo_transmision_agentes','Distancias entre granjas','Riesgo por moscas, aerosol o polvo','< 3','km','PRRS a 2.4 km por moscas, M. hyopneumoniae a 3.2 km por aerosol y PEDV por polvo','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Diapositiva Distancia',2),
 ('distancia_minima_prrs_mycoplasma','Distancias entre granjas','Distancia minima recomendada','> 10','km','Se minimiza el riesgo de PRRS (9.1 km) y Mycoplasma hyopneumoniae (9.2 km)','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Diapositiva Distancia',3),
 ('distancia_referencia_8km','Distancias entre granjas','Referencia de la diapositiva previa','8','km','Aparece como valor de referencia, sin fijar umbral','media','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Diapositiva previa a Distancia',4),
 ('distancia_referencia_80km','Distancias entre granjas','Referencia de la diapositiva previa','80','km','Aparece como valor de referencia, sin fijar umbral','media','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Diapositiva previa a Distancia',5),
 ('impacto_1pct_mortalidad_destete_engorde','KPIs impacto economico','1 % de mortalidad en destete y engorde','0.44 o 0.88','EUR/cerdo','Dos escenarios en la diapositiva','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Indicadores de desempeno (KPIs) e impacto (EUR)',1),
 ('impacto_100g_conversion_alimenticia','KPIs impacto economico','100 g de conversion alimenticia','0.59 o 3.84','EUR/cerdo','Dos escenarios en la diapositiva','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Indicadores de desempeno (KPIs) e impacto (EUR)',2),
 ('impacto_1psy','KPIs impacto economico','1 lechon destetado adicional (PSY)','1.4','EUR/lechon','Lechon destetado adicional por cerda al ano','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Indicadores de desempeno (KPIs) e impacto (EUR)',3),
 ('impacto_1dnp','KPIs impacto economico','1 dia no productivo','0.23','EUR/lechon','Dia no productivo','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Indicadores de desempeno (KPIs) e impacto (EUR)',4),
 ('probabilidad_brote_prrs_post_filtros','Filtracion de aire','Probabilidad de brote de PRRS tras instalar filtros','8 veces menor','factor','Reduccion descrita en la diapositiva de filtracion','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Diapositiva filtracion PRRS',1),
 ('clave_diseno_1','7 claves diseno granjas bioseguras','Localizacion ideal','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','7 claves para el diseno de granjas bioseguras',1),
 ('clave_diseno_2','7 claves diseno granjas bioseguras','Filtracion de aire (?)','','','Signo de interrogacion en el original','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','7 claves para el diseno de granjas bioseguras',2),
 ('clave_diseno_3','7 claves diseno granjas bioseguras','Flujo de reemplazo y lechones','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','7 claves para el diseno de granjas bioseguras',3),
 ('clave_diseno_4','7 claves diseno granjas bioseguras','Edificacion compacta','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','7 claves para el diseno de granjas bioseguras',4),
 ('clave_diseno_5','7 claves diseno granjas bioseguras','Area limpia definida y contenida','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','7 claves para el diseno de granjas bioseguras',5),
 ('clave_diseno_6','7 claves diseno granjas bioseguras','Minimos puntos comodos de entrada/salida','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','7 claves para el diseno de granjas bioseguras',6),
 ('clave_diseno_7','7 claves diseno granjas bioseguras','Interaccion adecuada con servicios externos','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','7 claves para el diseno de granjas bioseguras',7),
 ('area_sucia','Definicion de areas','Area sucia','Fuera de la cerca','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Definicion de area limpia',1),
 ('area_intermedia','Definicion de areas','Area intermedia','Entre caseta y cerca','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Definicion de area limpia',2),
 ('area_limpia','Definicion de areas','Area limpia','Caseta, pasillo, oficina, chute','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Definicion de area limpia',3),
 ('punto_cruce_duchas_banco','Puntos de cruce area limpia','Duchas / banco','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Definicion de area limpia (puntos de cruce LLS)',1),
 ('punto_cruce_sala_desinfeccion','Puntos de cruce area limpia','Sala de desinfeccion','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Definicion de area limpia (puntos de cruce LLS)',2),
 ('punto_cruce_camara_uv','Puntos de cruce area limpia','Camara de luz UV / ventana','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Definicion de area limpia (puntos de cruce LLS)',3),
 ('punto_cruce_extraccion_mortalidad','Puntos de cruce area limpia','Extraccion de mortalidad','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Definicion de area limpia (puntos de cruce LLS)',4),
 ('punto_cruce_embarcadero','Puntos de cruce area limpia','Embarcadero','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Definicion de area limpia (puntos de cruce LLS)',5),
 ('ruta_entrada_1','Rutas de entrada de enfermedades','Fauna, insectos, polvo, aerosol','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Rutas de entrada de las enfermedades a la granja',1),
 ('ruta_entrada_2','Rutas de entrada de enfermedades','Personas','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Rutas de entrada de las enfermedades a la granja',2),
 ('ruta_entrada_3','Rutas de entrada de enfermedades','Transporte','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Rutas de entrada de las enfermedades a la granja',3),
 ('ruta_entrada_4','Rutas de entrada de enfermedades','Alimento','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Rutas de entrada de las enfermedades a la granja',4),
 ('ruta_entrada_5','Rutas de entrada de enfermedades','Gestion de mortalidad','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Rutas de entrada de las enfermedades a la granja',5),
 ('ruta_entrada_6','Rutas de entrada de enfermedades','Materiales y equipos','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Rutas de entrada de las enfermedades a la granja',6),
 ('ruta_entrada_7','Rutas de entrada de enfermedades','Reposicion y semen','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Rutas de entrada de las enfermedades a la granja',7),
 ('ruta_entrada_8','Rutas de entrada de enfermedades','Manejo de purines','','','','alta','Concepto manejo y diseno de Bioseguridad (Jean Paul Cano, Pork School ago-2026)','Rutas de entrada de las enfermedades a la granja',8)
on conflict (id) do nothing;

notify pgrst,'reload schema';
commit;
