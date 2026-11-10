-- Endurece privilegios innecesarios del rol anon en el proyecto de pruebas.
-- RLS ya bloquea estas tablas para anon; se retiran grants que no tienen
-- politica anon asociada. Los usuarios autenticados conservan sus permisos.
revoke all privileges on table
  public.catalog_review_reports,
  public.catalog_review_status_history
from anon;

-- Estas funciones exigen auth.uid() o son internas/trigger. El unico hook
-- que debe seguir ejecutable por anon es public.beta_request_guard(), porque
-- PostgREST lo invoca como pre-request para solicitudes anonimas.
revoke execute on function private.beta_read_allowed() from anon;
revoke execute on function private.beta_request_guard() from anon;
revoke execute on function public.accept_clinic_invitation(text) from anon;
revoke execute on function public.create_clinic(text) from anon;
revoke execute on function public.prevent_last_clinic_admin_removal() from anon;
