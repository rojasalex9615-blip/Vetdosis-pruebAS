-- Convierte a numero la dosis de los textos que tienen UNA sola pauta.
--
-- POR QUE EXISTE. Dos mil seiscientas cincuenta y cuatro filas tienen la dosis
-- escrita en texto ('1 mL/50 kg') y no en numeros, asi que la calculadora no
-- puede precargar nada. La mayoria son inequivocas.
--
-- QUE HACE. vetdosis_reference_staging.dosis_numerica(texto) devuelve
-- {cantidad, unidad, kg} solo cuando el texto contiene EXACTAMENTE una tasa
-- 'X unidad / Y kg'. Esa tasa vale para todas las especies de la fila.
--
-- LO QUE NO HACE, A PROPOSITO. Devuelve NULL cuando:
--   - hay mas de una tasa (pauta por especie, dos vias, bandas de peso);
--   - la tasa trae un rango ('1-5 mL/10-50 kg', '1 mL/16-20 kg'): no hay un
--     unico kg de referencia y la calculadora proporcional daria un numero
--     inventado. Esos rangos se muestran como texto;
--   - la dosis no es por kg ('100 mL/dia', '200-250 ml/paciente',
--     '1 mL/animal', '10 mL/cuarto afectado');
--   - el texto no trae tasa reconocible.
-- Un NULL es correcto: significa 'esto necesita revision humana'. Inventar un
-- numero aqui seria peor que dejarlo vacio.
--
-- ORIGEN. La vista expone dosis_numerica_origen = 'texto_convertido' para que
-- se distinga de lo que ya venia numerico de la ficha.

begin;

create or replace function vetdosis_reference_staging.dosis_numerica(p_texto text)
returns jsonb language sql immutable as $$
  with num as (select '[0-9]+(?:\.[0-9]+)?' n),
  limpio as (
    -- El parentesis con especie es pauta aparte; aqui solo interesa la tasa
    -- general, asi que se descarta para no contar dos.
    select regexp_replace(
             coalesce(p_texto,''),
             '\([^()]*(?:bovinos?|porcinos?|ovinos?|caprinos?|equinos?|caninos?|felinos?|camélidos?)[^()]*\)',
             ' ', 'gi'
           ) t
  ),
  tasas as (
    select m[1] cantidad, lower(m[2]) unidad, m[3] kg
    from limpio, num
    cross join lateral regexp_matches(
      limpio.t,
      '(' || num.n || '(?:\s*-\s*' || num.n || ')?)\s*(mL|ml|mg|g|UI|µg)\s*/\s*(' ||
      num.n || '(?:\s*-\s*' || num.n || ')?)\s*kg',
      'g'
    ) m
  ),
  conteo as (
    select count(*) n,
           count(distinct cantidad || '|' || unidad || '|' || kg) distintas
    from tasas
  )
  select case
    when (select n from conteo) = 1
     and (select distintas from conteo) = 1
     and (select bool_and(cantidad ~ '^[0-9.]+$' and kg ~ '^[0-9.]+$') from tasas)
    then (select jsonb_build_object(
                 'cantidad', min(cantidad),
                 'unidad',   min(unidad),
                 'kg',       min(kg)
               )
          from tasas)
    else null
  end;
$$;

revoke all on function vetdosis_reference_staging.dosis_numerica(text) from public, anon, authenticated;

commit;
