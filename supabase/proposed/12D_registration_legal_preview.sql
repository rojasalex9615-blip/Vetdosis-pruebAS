-- 12D · Lectura sin sesión del par legal publicado.
--
-- `beta_status` exige sesión: sin token no hay forma de leer los términos y el
-- aviso que la puerta beta muestra y hace aceptar. Esta función publica solo
-- los documentos que el servidor ya marcó como publicados y cuya huella
-- coincide con su contenido, para que la letra pequeña del acceso muestre la
-- misma versión y la misma huella que después se aceptan.
--
-- No recibe parámetros, no escribe y no lee personas ni clínicas: únicamente
-- los textos legales vigentes. Es idempotente (`create or replace`).
create or replace function public.beta_registration_legal()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with published_terms as (
    select t.version, t.content, t.content_hash, t.privacy_version
    from private.beta_terms t
    where t.published
      and t.content_hash = encode(sha256(convert_to(t.content, 'UTF8')), 'hex')
    order by t.published_at desc nulls last, t.version desc
    limit 1
  )
  select jsonb_build_object(
    'terms', (
      select jsonb_build_object(
        'version', version,
        'hash', content_hash,
        'content', content
      )
      from published_terms
    ),
    'privacy', (
      select jsonb_build_object(
        'version', n.version,
        'hash', n.content_hash,
        'content', n.content
      )
      from private.beta_privacy_notices n
      join published_terms t on t.privacy_version = n.version
      where n.published
        and n.content_hash = encode(sha256(convert_to(n.content, 'UTF8')), 'hex')
    )
  );
$$;

-- Solo lectura pública: se retira de todos y se concede a anon y authenticated.
revoke all on function public.beta_registration_legal()
  from public, anon, authenticated;
grant execute on function public.beta_registration_legal()
  to anon, authenticated;

comment on function public.beta_registration_legal() is
  'Par legal publicado (términos de uso y aviso de privacidad) para consulta sin sesión. Solo lectura.';

notify pgrst, 'reload schema';
