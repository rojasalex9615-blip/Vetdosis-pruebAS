import contextlib
import io
import os
import unittest
from unittest.mock import patch
import pautas_intake as deploy


class PautasIntakeGuards(unittest.TestCase):
    def state(self, **updates):
        state = {
            'staging_ready': True,
            'batches_ready': True,
            'permission_ready': True,
            'review_fn_exists': False,
            'batch_present': False,
            'pauta_rows': 0,
        }
        state.update(updates)
        return state

    def run_mode(self, state, confirmation='ACTIVAR_PAUTAS_EN_PRUEBAS', mode='apply'):
        with patch.dict(os.environ, {'PAUTAS_ACTION': mode, 'PAUTAS_CONFIRMATION': confirmation}), patch.object(deploy, 'query', return_value=[state]) as query, contextlib.redirect_stdout(io.StringIO()):
            try:
                deploy.main()
            except SystemExit:
                pass
            # Todo rechazo o inspección debe emitir solo el preflight de lectura.
            self.assertEqual(query.call_count, 1)
            self.assertEqual(query.call_args.args, (deploy.PREFLIGHT,))

    def test_preflight_never_writes(self):
        self.run_mode(self.state(), mode='inspect')

    def test_missing_confirmation_never_writes(self):
        self.run_mode(self.state(), confirmation='otro proyecto')

    def test_missing_staging_never_writes(self):
        self.run_mode(self.state(staging_ready=False))

    def test_missing_permission_helper_never_writes(self):
        self.run_mode(self.state(permission_ready=False))

    def test_apply_sends_only_the_two_reviewed_migrations(self):
        before = self.state()
        after = self.state(review_fn_exists=True, batch_present=True, pauta_rows=1197)
        with patch.dict(os.environ, {'PAUTAS_ACTION': 'apply', 'PAUTAS_CONFIRMATION': 'ACTIVAR_PAUTAS_EN_PRUEBAS'}), patch.object(deploy, 'query', side_effect=[[before], [], [], [after]]) as query, contextlib.redirect_stdout(io.StringIO()):
            deploy.main()
            self.assertEqual(query.call_count, 4)
            intake_sql = query.call_args_list[1].args[0]
            read_sql = query.call_args_list[2].args[0]
            self.assertIn('insert into vetdosis_reference_staging.raw_intake_rows', intake_sql)
            self.assertIn("'pending'", intake_sql)
            self.assertIn('on conflict (batch_id,row_key) do nothing', intake_sql)
            self.assertIn('create or replace function public.review_pauta_list', read_sql)
            # Nunca se activa una regla de cálculo desde la ingesta.
            self.assertNotIn('habilitado_en_app=true', intake_sql + read_sql)


if __name__ == '__main__':
    unittest.main()
