-- Mismo agujero que se detecto en exoticos, y por la misma causa: los
-- privilegios por omision del esquema public le dan a `authenticated` y a
-- `anon` INSERT, UPDATE, DELETE y TRUNCATE sobre cualquier tabla nueva.
--
-- Los tres primeros los frena RLS, porque no hay politica que los permita,
-- pero TRUNCATE NO pasa por RLS: con ese privilegio cualquiera con sesion
-- podria vaciar las gestaciones de cualquier clinica.
--
-- authenticated se queda solo con SELECT. Toda escritura entra por los dos
-- RPC SECURITY DEFINER.

revoke insert, update, delete, truncate, references, trigger
  on public.reproduccion_gestaciones, public.reproduccion_gestacion_dias
  from authenticated;

-- anon no tiene nada que hacer aqui, ni siquiera en el catalogo.
revoke all on public.reproduccion_gestaciones, public.reproduccion_gestacion_dias from anon;

-- El catalogo de dias si es consulta legitima para cualquiera con sesion.
grant select on public.reproduccion_gestacion_dias to authenticated;
grant select on public.reproduccion_gestaciones to authenticated;
