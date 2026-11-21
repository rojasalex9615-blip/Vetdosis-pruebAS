-- Normaliza el formato del texto de dosis, sin tocar las cifras.
--
-- POR QUE EXISTE. La misma idea aparece escrita de muchas formas: '1 ml / 10 kg'
-- y '1 ml/10 kg', 'cada 12 h' y 'cada 12 horas', 'mcg' y 'µg', 'cc' y 'mL'. Eso
-- impide buscar y comparar. Tambien hay 22 textos que empiezan en minuscula y 58
-- rangos escritos con 'y' ('2 y 4 ml') en vez de guion.
--
-- QUE HACE. Solo formato: espacios, barra de dosis, unidades y mayuscula inicial.
-- No convierte unidades (no pasa mg a mL), no redondea, no cambia cifras y no
-- interpreta la posologia. Si una regla no esta segura, no se aplica.
--
-- COMO. dosis_texto_limpio() es idempotente: aplicarla dos veces da lo mismo.
-- La vista vademecum_producto_por_especie expone dosis_texto_limpio junto al
-- original, para poder comparar y revertir sin perder nada.

begin;

create or replace function vetdosis_reference_staging.dosis_texto_limpio(p_texto text)
returns text language sql immutable as $$
  with paso1 as (
    select btrim(regexp_replace(coalesce(p_texto,''), '\s+', ' ', 'g')) t
  ),
  paso2 as (
    -- 'ml / 10 kg' -> 'ml/10 kg': la barra de dosis va pegada a la unidad.
    select regexp_replace(t, '\s*/\s*', '/', 'g') t from paso1
  ),
  paso3 as (
    -- '1.5ml' -> '1.5 ml', pero sin tocar '1.5' ni 'kg'.
    select regexp_replace(t, '([0-9])(ml|mL|ML|mg|MG|g|kg|UI|U\.I\.|µg|mcg)\y',
                          '\1 \2', 'gi') t from paso2
  ),
  paso4 as (
    select regexp_replace(t, '\m(mcg|ug|µg|µg)\M', 'µg', 'gi') t from paso3
  ),
  paso5 as (
    select regexp_replace(t, '\mcc\M', 'mL', 'gi') t from paso4
  ),
  paso6 as (
    -- 'cada 12 horas' -> 'cada 12 h'
    select regexp_replace(t, '\mcada ([0-9]+(?:\.[0-9]+)?) horas\M', 'cada \1 h', 'gi') t from paso5
  ),
  paso7 as (
    -- '2 y 4 ml' -> '2-4 ml' solo entre cifras con unidad detras.
    select regexp_replace(t, '([0-9]) y ([0-9]+ (?:ml|mg|g|kg|UI|µg))', '\1-\2', 'g') t from paso6
  ),
  paso8 as (
    -- 'ml/kg de P.C.' -> 'mL/kg de P.C.' sin cambiar el resto.
    select regexp_replace(t, '\mml\M', 'mL', 'gi') t from paso7
  ),
  paso9 as (
    -- Mayuscula inicial, salvo cuando el texto es solo una unidad ('mg', 'mL').
    select case
             when t ~* '^(mg|ml|g|kg|ui|µg|cc|sobre|tableta|cápsula|gota|tubo|dosis)$' then t
             when t ~ '^[a-záéíóúñ]' then upper(left(t,1)) || substr(t,2)
             else t
           end t
    from paso8
  )
  select nullif(t,'') from paso9;
$$;

revoke all on function vetdosis_reference_staging.dosis_texto_limpio(text) from public, anon, authenticated;

commit;
