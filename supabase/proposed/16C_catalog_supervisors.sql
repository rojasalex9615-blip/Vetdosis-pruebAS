-- 16C · Supervisores del catálogo (administradores secundarios de la app).
-- Apply after 12B. Requires the beta gate (09A/09B) and the catalog review
-- scope migrations (202611110001..202611110006).
--
-- POR QUE EXISTE. El catálogo de la app (estado global) solo lo escribe
-- review_catalog_set_global_status, que exige private.is_catalog_platform_owner().
-- Esa lista se llenaba a mano en la base: no había forma de nombrar a nadie
-- desde la app. Esta migración añade la lectura, la designación y la revocación
-- de supervisores desde el panel de administración de plataforma.
--
-- ALCANCE. Solo el administrador de plataforma (cuenta separada, con 2FA y sin
-- clínica) lista, nombra y revoca supervisores. Un supervisor valida el catálogo
-- compartido; no administra la plataforma ni recibe permisos clínicos. Las
-- clínicas y las personas siguen validando su propio ámbito, nunca el global.
begin;

-- El administrador de plataforma también valida el catálogo compartido, como
-- pidió el dueño: es su propia app. Un supervisor es cualquier otra persona
-- designada para esa tarea. Ninguno de los dos gana permisos clínicos.
create or replace function private.is_catalog_platform_owner()
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and (
    exists(select 1 from private.catalog_platform_owners o where o.user_id=auth.uid())
    or exists(select 1 from private.platform_admins a where a.user_id=auth.uid() and a.enabled)
  );
$$;

create or replace function public.platform_catalog_supervisor_list()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  perform private.require_platform_admin();
  return coalesce((select jsonb_agg(jsonb_build_object(
    'user_id',o.user_id,'email',u.email,'created_at',o.created_at,
    'is_platform_admin',exists(select 1 from private.platform_admins a
      where a.user_id=o.user_id and a.enabled))
    order by o.created_at desc)
    from private.catalog_platform_owners o
    left join auth.users u on u.id=o.user_id),'[]');
end$$;

-- Designa supervisor por correo. Exige que la persona ya exista con el correo
-- confirmado: no se inventan cuentas ni se piden datos fuera de la app.
create or replace function public.platform_catalog_supervisor_grant(p_email text,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_email text;v_user uuid;
begin
  perform private.require_platform_admin();
  v_email=private.beta_normalize_email(p_email);
  if p_reason is null or length(btrim(p_reason)) not between 5 and 1000 then
    raise exception 'reason_required';
  end if;
  select id into v_user from auth.users
    where lower(btrim(email))=v_email and email_confirmed_at is not null;
  if v_user is null then raise exception 'registered_confirmed_email_required';end if;
  insert into private.catalog_platform_owners(user_id) values(v_user)
    on conflict(user_id) do nothing;
  insert into private.beta_audit(actor_id,action,entity_id,reason)
    values(auth.uid(),'catalog_supervisor_granted',v_user::text,p_reason);
  return v_user;
end$$;

create or replace function public.platform_catalog_supervisor_revoke(p_user_id uuid,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
begin
  perform private.require_platform_admin();
  if p_reason is null or length(btrim(p_reason)) not between 5 and 1000 then
    raise exception 'reason_required';
  end if;
  if p_user_id=auth.uid() then raise exception 'self_revocation_forbidden';end if;
  delete from private.catalog_platform_owners where user_id=p_user_id;
  if not found then raise exception 'catalog_supervisor_not_found';end if;
  insert into private.beta_audit(actor_id,action,entity_id,reason)
    values(auth.uid(),'catalog_supervisor_revoked',p_user_id::text,p_reason);
end$$;

-- La guarda beta cubre catalog_platform_owners; sin esta excepción, al activar
-- la beta (enforcement_enabled) designar o revocar un supervisor fallaría con
-- beta_workspace_read_only. Es el mismo caso que professional_revocations en 12B.
create or replace function private.beta_write_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare item jsonb;scope uuid;state jsonb;begin
 if not (select enforcement_enabled from private.beta_policy) then if tg_op='DELETE' then return old;end if;return new;end if;
 -- Trusted service jobs remain server-only. A security-definer RPC does not change the request role GUC.
 if auth.uid() is null and (coalesce(auth.jwt()->>'role','')='service_role' or current_setting('role',true) in ('none','postgres','service_role')) then if tg_op='DELETE' then return old;end if;return new;end if;
 item=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
 if tg_table_schema='public' and tg_table_name='audit_log' and item->>'action'='operational_backup_exported' and item->>'actor_id'=auth.uid()::text then perform public.beta_access_check(false);return new;end if;
 -- Narrow legal-consent exception; direct client INSERT remains revoked.
 if tg_table_schema='public' and tg_table_name='terms_acceptances' and tg_op='INSERT'
 and item->>'user_id'=auth.uid()::text and item->>'origin'='explicit'
 and exists(select 1 from private.beta_terms t where t.version=item->>'terms_version' and t.content_hash=item->>'terms_hash' and t.published and t.version=(private.beta_latest_terms()).version)
 then return new;end if;
 -- A separate platform administrator is not a clinical beta participant.
 if tg_table_schema='private' and tg_table_name='professional_revocations' and tg_op='INSERT'
 and item->>'revoked_by'=auth.uid()::text and exists(select 1 from private.professional_verifications v where v.id=(item->>'verification_id')::uuid and v.clinic_id is null and v.origin='platform_external') then
 perform private.require_platform_admin();return new;end if;
 -- Naming a catalog supervisor is a platform administration act, not clinic data.
 if tg_table_schema='private' and tg_table_name='catalog_platform_owners' then
 perform private.require_platform_admin();if tg_op='DELETE' then return old;end if;return new;end if;
 state=public.beta_access_check(true);
 begin scope=nullif(item->>'clinic_id','')::uuid;exception when invalid_text_representation then scope=null;end;
 if tg_table_schema='public' and tg_table_name='clinics' then scope=(item->>'id')::uuid;end if;
 if tg_table_schema='storage' and item->>'bucket_id'='inventory-photos' then begin scope=split_part(item->>'name','/',1)::uuid;exception when others then scope=null;end;end if;
 if scope is not null and tg_table_name not in ('audit_log','workspace_usage') then
  -- Clinic creation and its creator's initial admin membership are a bounded bootstrap;
  -- recording clinic data subsequently requires explicit sponsor acceptance.
  if not(tg_op='INSERT' and ((tg_table_name='clinics' and item->>'created_by'=auth.uid()::text) or (tg_table_name='clinic_members' and item->>'user_id'=auth.uid()::text and item->>'role'='admin' and exists(select 1 from public.clinics where id=scope and created_by=auth.uid())))) then
   state=private.beta_mode(null,scope,not(tg_table_name='clinic_members' and tg_op='INSERT'));
   if state->>'mode' not in ('active','sponsor_grace','internal') then raise exception 'beta_workspace_read_only';end if;
  end if;
 end if;
 if tg_op='DELETE' then return old;end if;return new;
end$$;

revoke all on function public.platform_catalog_supervisor_list(),
  public.platform_catalog_supervisor_grant(text,text),
  public.platform_catalog_supervisor_revoke(uuid,text) from public,anon;
grant execute on function public.platform_catalog_supervisor_list(),
  public.platform_catalog_supervisor_grant(text,text),
  public.platform_catalog_supervisor_revoke(uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;
