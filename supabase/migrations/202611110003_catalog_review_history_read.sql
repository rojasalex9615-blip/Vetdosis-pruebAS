-- Scoped catalog review history is readable only inside its own authority boundary.
create or replace function public.review_catalog_history(
  p_scope text,
  p_clinic uuid default null,
  p_source_key text default null,
  p_limit integer default 100
) returns table(
  scope text, clinic_id uuid, user_id uuid, source_key text,
  catalog_version text, previous_status text, new_status text,
  actor_id uuid, changed_at timestamptz
) language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_scope not in ('global','clinic','personal') then
    raise exception 'invalid_review_scope' using errcode='22023';
  end if;
  if p_scope='global' and not private.is_catalog_platform_owner() then
    raise exception 'platform_catalog_owner_required' using errcode='42501';
  elsif p_scope='clinic' and (p_clinic is null or not private.has_clinic_role(p_clinic,array['admin','revisor'])) then
    raise exception 'review_access_denied' using errcode='42501';
  elsif p_scope='personal' and p_clinic is not null then
    raise exception 'invalid_review_scope_target' using errcode='22023';
  end if;

  return query
  select h.scope,h.clinic_id,h.user_id,h.source_key,h.catalog_version,
    h.previous_status,h.new_status,h.actor_id,h.changed_at
  from private.catalog_review_scoped_history h
  where h.scope=p_scope
    and (p_scope <> 'clinic' or h.clinic_id=p_clinic)
    and (p_scope <> 'personal' or h.user_id=auth.uid())
    and (p_source_key is null or h.source_key=p_source_key)
  order by h.changed_at desc
  limit least(greatest(coalesce(p_limit,100),1),200);
end;
$$;
revoke all on function public.review_catalog_history(text,uuid,text,integer) from public, anon;
grant execute on function public.review_catalog_history(text,uuid,text,integer) to authenticated;
