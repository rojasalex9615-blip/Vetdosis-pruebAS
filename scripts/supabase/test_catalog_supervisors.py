import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SQL = (ROOT / 'supabase/proposed/16C_catalog_supervisors.sql').read_text()


class CatalogSupervisorGuards(unittest.TestCase):
    def test_only_platform_admin_manages_supervisors(self):
        # Cada función exige la cuenta de plataforma con 2FA.
        for name in (
            'platform_catalog_supervisor_list',
            'platform_catalog_supervisor_grant',
            'platform_catalog_supervisor_revoke',
        ):
            start = SQL.index('function public.' + name)
            end = SQL.index('$$;', start)
            body = SQL[start:end]
            self.assertIn('perform private.require_platform_admin();', body)

    def test_grant_requires_a_registered_confirmed_email(self):
        self.assertIn('email_confirmed_at is not null', SQL)
        self.assertIn('registered_confirmed_email_required', SQL)

    def test_reason_is_required_and_self_revocation_is_blocked(self):
        self.assertIn("raise exception 'reason_required'", SQL)
        self.assertIn('self_revocation_forbidden', SQL)

    def test_platform_admin_keeps_the_shared_catalog(self):
        # El dueño de la app valida el catálogo compartido además de sus supervisores.
        self.assertIn('from private.platform_admins a where a.user_id=auth.uid() and a.enabled', SQL)
        self.assertIn('or exists(select 1 from private.platform_admins', SQL)

    def test_write_guard_covers_supervisor_naming(self):
        # Sin esta excepción, activar la beta rompería la designación de supervisores.
        self.assertIn("tg_table_name='catalog_platform_owners'", SQL)
        self.assertIn('beta_workspace_read_only', SQL)

    def test_supervisors_get_no_table_privileges(self):
        # Los supervisores no reciben permisos directos de tabla: solo RPC.
        self.assertIn('revoke all on function', SQL)
        self.assertIn('to authenticated;', SQL)
        self.assertNotIn('grant insert on', SQL.lower())

    def test_reapplying_changes_nothing(self):
        # Reaplicar la migración debe dejar el mismo estado (create or replace).
        self.assertNotIn('\ncreate function public.', SQL)
        self.assertNotIn('create function private.', SQL)
        for name in (
            'is_catalog_platform_owner',
            'beta_write_guard',
            'platform_catalog_supervisor_list',
            'platform_catalog_supervisor_grant',
            'platform_catalog_supervisor_revoke',
        ):
            start = SQL.index('function private.' + name) if name in (
                'is_catalog_platform_owner',
                'beta_write_guard',
            ) else SQL.index('function public.' + name)
            self.assertTrue(
                SQL[:start].rstrip().endswith('create or replace'),
                name + ' debe reaplicarse sin error',
            )


if __name__ == '__main__':
    unittest.main()
