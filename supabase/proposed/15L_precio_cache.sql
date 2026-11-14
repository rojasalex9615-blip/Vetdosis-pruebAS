-- PROPUESTA, NO APLICADA. Cache de precios estimados por busqueda web y
-- contador de cuota.
--
-- Numerada 15L y no 15K: el 15K ya estaba reclamado por
-- 15K_porcino_produccion.sql, la reescritura de las tablas porcinas de
-- Gemini que quedo en la rama feature/porcino-tablas-propuesta-20261106 del
-- repositorio suspendido. Ese archivo no esta ni en GitLab ni en la cuenta
-- nueva: comprobado contra los dos remotos. Se deja el numero libre para
-- cuando se recupere, en vez de reusarlo y tener dos 15K.
--
-- Sin catalogo de productos: una fila por concepto.
-- Revisada sobre la propuesta de Sonnet; los cambios y por que van abajo.
--
-- 1. La reserva de cuota NO puede vivir en `private`. La funcion de servidor
--    la llamaria por RPC de PostgREST, y PostgREST solo expone los esquemas
--    publicados: una llamada a private.* no existe para el cliente, con llave
--    de servicio o sin ella. Pasa a public, revocada de todos y concedida
--    solo a service_role.
-- 2. El rol va como array['admin'] sin convertir, que es como lo escribe el
--    resto del repositorio. `::text[]` fija la llamada a una de las dos
--    definiciones de private.has_clinic_role que conviven aqui (una toma
--    public.clinic_role[] y la de adaptations toma text[]), y en la base que
--    no tenga esa, falla.
-- 3. Todo dentro de begin/commit, como los demas archivos de proposed.
-- 4. Restricciones que faltaban: la mediana tiene que caer dentro del rango,
--    y no puede haber mas tiendas que precios.
-- 5. La unicidad va sobre el concepto normalizado. Sin eso «Ventilador» y
--    «ventilador » son dos filas, y cada una gasta una busqueda de la cuota.

begin;

create table if not exists public.precio_cache (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  concepto text not null check (length(btrim(concepto)) between 1 and 120),
  unidad text not null check (length(btrim(unidad)) between 1 and 30),
  consulta text not null check (length(consulta) <= 200),
  moneda text not null default 'MXN' check (moneda = 'MXN'),
  mediana_centavos bigint not null check (mediana_centavos > 0),
  bajo_centavos bigint not null check (bajo_centavos > 0),
  alto_centavos bigint not null check (alto_centavos >= bajo_centavos),
  precios_usados int not null check (precios_usados >= 1),
  precios_descartados int not null default 0 check (precios_descartados >= 0),
  fuentes int not null check (fuentes >= 1),
  buscado_en timestamptz not null default now(),
  expira_en timestamptz not null default now() + interval '30 days',
  -- La mediana fuera de su propio rango seria un error de calculo, no un dato.
  constraint precio_cache_mediana_en_rango
    check (mediana_centavos between bajo_centavos and alto_centavos),
  -- No puede haber mas tiendas distintas que precios tomados.
  constraint precio_cache_fuentes_coherentes check (fuentes <= precios_usados)
);

-- Normalizada: el espacio sobrante y las mayusculas no crean filas nuevas,
-- que ademas gastarian cuota.
create unique index if not exists precio_cache_concepto_unico
  on public.precio_cache (clinic_id, lower(btrim(concepto)), lower(btrim(unidad)));

-- Para la limpieza de lo vencido.
create index if not exists precio_cache_expira
  on public.precio_cache (expira_en);

alter table public.precio_cache enable row level security;
revoke all on public.precio_cache from public, anon, authenticated;
grant select on public.precio_cache to authenticated;

create policy precio_cache_admin_read on public.precio_cache
  for select to authenticated
  using (private.has_clinic_role(clinic_id, array['admin']));

-- Cuota de la llave. Es una sola llave para toda la app, asi que el contador
-- es global: una clinica puede agotar la cuota de las demas. Queda asi a
-- proposito mientras la llave sea una; si deja de serlo, esto necesita
-- clinic_id y otra politica.
create table if not exists public.precio_cuota (
  periodo date primary key,
  usadas int not null default 0 check (usadas >= 0),
  tope int not null check (tope > 0)
);
alter table public.precio_cuota enable row level security;
revoke all on public.precio_cuota from public, anon, authenticated;

-- Reserva una busqueda de forma atomica. false = cuota agotada.
--
-- La condicion `usadas < tope` dentro del UPDATE es lo que hace la reserva
-- segura con llamadas simultaneas: la segunda espera el bloqueo de fila y
-- vuelve a evaluarla contra la version ya actualizada, asi que no se pasa
-- del tope. No basta con leer y luego escribir.
create or replace function public.precio_reservar_busqueda(p_tope int)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_periodo date := date_trunc('month', now())::date;
  v_ok boolean;
begin
  if p_tope is null or p_tope <= 0 then
    raise exception 'tope invalido';
  end if;
  insert into public.precio_cuota (periodo, usadas, tope)
  values (v_periodo, 0, p_tope)
  on conflict (periodo) do update set tope = excluded.tope;

  update public.precio_cuota
     set usadas = usadas + 1
   where periodo = v_periodo and usadas < tope
  returning true into v_ok;
  return coalesce(v_ok, false);
end;
$$;

revoke all on function public.precio_reservar_busqueda(int)
  from public, anon, authenticated;
grant execute on function public.precio_reservar_busqueda(int) to service_role;

notify pgrst, 'reload schema';

commit;
