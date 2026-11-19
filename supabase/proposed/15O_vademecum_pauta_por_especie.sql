-- Extrae la pauta que el texto asigna a cada especie, cuando el texto las separa.
--
-- POR QUE EXISTE. Setenta y cuatro productos traen varias pautas en un solo
-- texto. Siete de ellos dan una pauta DISTINTA por especie:
--
--   'Bovinos 1 mL/50 kg; Ovinos/Caprinos 0.5 mL/25 kg; Porcinos 1 mL/33 kg'
--
-- Si ese texto se convierte a numero de golpe, el ovino recibe 1 mL/50 kg
-- cuando su ficha dice 0.5 mL/25 kg: la mitad de la dosis. La vista repetia el
-- mismo texto para todas las especies, asi que el error era invisible.
--
-- QUE HACE. vetdosis_reference_staging.pauta_por_especie(texto) devuelve un
-- jsonb {especie: {cantidad, unidad, kg}}. Parte el texto por ';' y asigna a
-- cada especie la pauta del segmento donde aparece nombrada.
--
-- LO QUE NO HACE. No interpreta segmentos sin especie (esos no se asignan a
-- nadie: mejor vacio que equivocado). No convierte unidades ni redondea. No
-- toca productos con una sola pauta para todas las especies: de esos se encarga
-- la conversion del grupo 1.
--
-- TRAMPA CONOCIDA. 'Bovinos' contiene 'ovinos'. Sin limites de palabra, el
-- ovino hereda la dosis del bovino. Por eso se comparan palabras completas.

begin;

create or replace function vetdosis_reference_staging.especie_en_segmento(p_seg text)
returns text[] language sql immutable as $$
  select coalesce(array_agg(e), '{}')
  from (values
    ('bovino',  '(bovinos?|vacunos?|becerros?|terneros?|novillos?)'),
    ('porcino', '(porcinos?|cerdos?|lechones?)'),
    ('equino',  '(equinos?|caballos?|yeguas?|potros?)'),
    ('ovino',   '(ovinos?|ovejas?|corderos?)'),
    ('caprino', '(caprinos?|cabritos?|cabras?)'),
    ('canino',  '(caninos?|perros?)'),
    ('felino',  '(felinos?|gatos?)'),
    ('aviar',   '(aviar|aves|pollos?|gallinas?)'),
    ('camélido','(camélidos?|alpacas?|llamas?)')
  ) as t(e, patron)
  where lower(p_seg) ~ ('(^|[^a-záéíóúñ])' || patron || '($|[^a-záéíóúñ])');
$$;

create or replace function vetdosis_reference_staging.pauta_por_especie(p_texto text)
returns jsonb language sql immutable as $$
  with num as (
    select '[0-9]+(?:\.[0-9]+)?' n
  ),
  segs as (
    select btrim(s) seg, ord
    from regexp_split_to_table(coalesce(p_texto,''), ';') with ordinality as x(s, ord)
    where btrim(s) <> ''
  ),
  tasas as (
    select
      s.seg,
      vetdosis_reference_staging.especie_en_segmento(s.seg) esp,
      m[1] cantidad,
      lower(m[2]) unidad,
      m[3] kg
    from segs s
    cross join num
    cross join lateral regexp_matches(
      s.seg,
      '(' || num.n || '(?:\s*-\s*' || num.n || ')?)\s*(mL|ml|mg|g|UI|µg)\s*/\s*(' ||
      num.n || '(?:\s*-\s*' || num.n || ')?)\s*kg',
      'g'
    ) m
  ),
  asignado as (
    select esp, cantidad, unidad, kg, seg
    from tasas
    where cardinality(esp) > 0
  )
  select coalesce(jsonb_object_agg(e, pauta), '{}'::jsonb)
  from (
    select
      e,
      jsonb_build_object(
        'cantidad', min(cantidad),
        'unidad',   min(unidad),
        'kg',       min(kg),
        'texto',    min(seg)
      ) pauta
    from asignado, unnest(esp) e
    group by e
    having count(distinct cantidad || unidad || kg) = 1
  ) x;
$$;

revoke all on function vetdosis_reference_staging.especie_en_segmento(text) from public, anon, authenticated;
revoke all on function vetdosis_reference_staging.pauta_por_especie(text) from public, anon, authenticated;

commit;
