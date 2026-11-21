-- Contrato de unicidad del catálogo Qwen; ejecutar tras 17A.
-- Falla si vuelve a haber un id_farmaco_original o id_dosis_original que
-- designe dos filas distintas, o si una dosis se queda sin fármaco.
begin;
do $$
declare
  v_dup text;
  v_n integer;
begin
  select string_agg(id_farmaco_original, ', ' order by id_farmaco_original) into v_dup
    from (select id_farmaco_original from private.vetdosis_qwen_farmacos_revision
           group by 1 having count(*) > 1) z;
  if v_dup is not null then
    raise exception 'id_farmaco_original duplicado: %', v_dup;
  end if;

  select string_agg(id_dosis_original, ', ' order by id_dosis_original) into v_dup
    from (select id_dosis_original from private.vetdosis_qwen_dosis_revision
           group by 1 having count(*) > 1) z;
  if v_dup is not null then
    raise exception 'id_dosis_original duplicado: %', v_dup;
  end if;

  select count(*) into v_n
    from private.vetdosis_qwen_dosis_revision d
   where not exists (select 1 from private.vetdosis_qwen_farmacos_revision f
                      where f.id_farmaco_original = d.id_farmaco_original);
  if v_n > 0 then raise exception '% dosis sin fármaco', v_n; end if;

  select count(*) into v_n
    from private.vetdosis_qwen_marcas_revision m
   where not exists (select 1 from private.vetdosis_qwen_farmacos_revision f
                      where f.id_farmaco_original = m.id_farmaco_original);
  if v_n > 0 then raise exception '% marcas sin fármaco', v_n; end if;

  -- Las dos moléculas que compartían F094 deben seguir siendo distinguibles.
  select count(*) into v_n
    from private.vetdosis_qwen_farmacos_revision
   where principio_activo in ('Propofol', 'Omeprazol');
  if v_n <> 2 then
    raise exception 'Propofol y Omeprazol deben existir por separado (hay %)', v_n;
  end if;
end$$;
rollback;
