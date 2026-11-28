-- Correccion. La migracion anterior reescribio produccion_evento_guardar de
-- memoria y perdio cuatro cosas del original:
--   * insertaba en `created_by`, pero la columna real es `registrado_por`;
--   * ponia null en `subtipo`, que es NOT NULL;
--   * quitaba el limite de 6000 bytes de `detalle`;
--   * dejaba fuera `animales` y `detalle` de la huella de idempotencia, con lo
--     que dos eventos que solo se diferenciaran en eso se habrian confundido.
-- Esta version es la original exacta, con 'reproductivo' como unico anadido.

create or replace function public.produccion_evento_guardar(p_clinic uuid,p_lote uuid,p_fecha date,p_tipo text,p_subtipo text,p_animales integer,p_detalle jsonb,p_operation text)
returns uuid language plpgsql security definer set search_path='' as $function$
declare v_id uuid;v_fp jsonb;
begin
 if auth.uid() is null then raise exception 'authentication_required';end if;
 if not private.has_clinic_role(p_clinic,array['admin','mvz','auxiliar']::text[]) then raise exception 'produccion_write_required';end if;
 if p_fecha is null or p_fecha>current_date then raise exception 'invalid_fecha';end if;
 if p_tipo is null or p_tipo not in ('sanitario','mortalidad','pesaje','traslado','sacrificio','reproductivo','otro') then raise exception 'invalid_tipo';end if;
 if char_length(btrim(coalesce(p_subtipo,'')))>60 then raise exception 'subtipo_too_long';end if;
 if p_tipo in ('sanitario','reproductivo') and char_length(btrim(coalesce(p_subtipo,'')))<1 then raise exception 'subtipo_required';end if;
 if p_animales is not null and (p_animales<0 or p_animales>1000000) then raise exception 'invalid_animales';end if;
 if jsonb_typeof(coalesce(p_detalle,'{}'::jsonb)) is distinct from 'object' or octet_length(coalesce(p_detalle,'{}'::jsonb)::text)>6000 then raise exception 'invalid_detalle';end if;
 if not exists(select 1 from public.lotes_produccion where id=p_lote and clinic_id=p_clinic) then raise exception 'lote_not_found';end if;
 v_fp=jsonb_build_object('kind','produccion_evento','lote',p_lote,'fecha',p_fecha,'tipo',p_tipo,'subtipo',coalesce(p_subtipo,''),'animales',p_animales,'detalle',coalesce(p_detalle,'{}'::jsonb));
 v_id=private.vet_receipt(p_clinic,p_operation,v_fp);if v_id is not null then return v_id;end if;
 perform 1 from public.clinics where id=p_clinic for update;
 insert into public.produccion_eventos(clinic_id,lote_id,fecha,tipo,subtipo,animales_afectados,detalle,registrado_por)
 values(p_clinic,p_lote,p_fecha,p_tipo,btrim(coalesce(p_subtipo,'')),p_animales,coalesce(p_detalle,'{}'::jsonb),auth.uid())
 returning id into v_id;
 insert into public.audit_log(clinic_id,actor_id,action,entity_id,details) values(p_clinic,auth.uid(),'produccion_evento_saved',v_id::text,jsonb_build_object('lote_id',p_lote,'tipo',p_tipo,'subtipo',coalesce(p_subtipo,'')));
 insert into private.vet_operation_receipts values(auth.uid(),p_clinic,p_operation,v_fp,v_id);
 return v_id;
end$function$;

notify pgrst,'reload schema';
