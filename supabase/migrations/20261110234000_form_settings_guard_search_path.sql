-- La funcion solo emite una excepcion y no necesita resolver objetos
-- por search_path. Se fija vacio para evitar resolucion de nombres mutable.
create or replace function private.form_settings_guard()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  raise exception 'setting_version_is_immutable';
end
$function$;
