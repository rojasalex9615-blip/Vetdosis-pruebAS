-- Correccion de seguridad detectada al auditar las concesiones reales.
--
-- Los privilegios por omision del esquema public le daban a `authenticated`
-- INSERT, UPDATE, DELETE y TRUNCATE sobre las ocho tablas nuevas. Los tres
-- primeros los frena RLS porque no existe ninguna politica que los permita,
-- pero **TRUNCATE no pasa por RLS**: con ese privilegio cualquier usuario con
-- sesion iniciada podia vaciar las tablas de cualquier clinica.
--
-- Por eso aqui se deja a `authenticated` unicamente con SELECT. Toda escritura
-- entra por los RPC SECURITY DEFINER, que son los que comprueban rol, validan
-- la entrada y dejan rastro en audit_log.

revoke insert, update, delete, truncate, references, trigger
  on public.exotic_enclosures,
     public.exotic_enclosure_readings,
     public.exotic_identifiers,
     public.exotic_legal_status,
     public.exotic_feedings,
     public.exotic_clutches,
     public.exotic_events,
     public.exotic_quarantine_plans
  from authenticated;

-- anon no tiene nada que hacer en el expediente de un ejemplar.
revoke all on public.exotic_enclosures,
     public.exotic_enclosure_readings,
     public.exotic_identifiers,
     public.exotic_legal_status,
     public.exotic_feedings,
     public.exotic_clutches,
     public.exotic_events,
     public.exotic_quarantine_plans
  from anon;
