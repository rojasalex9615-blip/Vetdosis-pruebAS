import contextlib
import io
import os
import unittest
from unittest.mock import patch
import publish_beta_build as publish

ROW = {
    'version_code': 42,
    'released_at': '2026-11-06T10:00:00+00:00',
    'expires_at': '2027-02-04T10:00:00+00:00',
}


class PublishBetaBuild(unittest.TestCase):
    def run_script(self, env, rows):
        calls = []

        def fake_query(sql):
            calls.append(sql)
            return rows if 'beta_builds' in sql else [{'beta_publish_build': None}]

        out, err = io.StringIO(), io.StringIO()
        with patch.dict(os.environ, env, clear=True), patch.object(publish, 'query', side_effect=fake_query), contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            status = None
            try:
                status = publish.main()
            except SystemExit as exit_:
                status = exit_.code
        return status, calls, out.getvalue(), err.getvalue()

    def test_missing_secret_never_registers(self):
        status, calls, _, err = self.run_script({'BETA_VERSION_CODE': '42'}, [ROW])
        self.assertEqual(status, 0)
        self.assertEqual(calls, [])
        self.assertIn('OMITIDO', err)

    def test_registers_then_confirms_the_row(self):
        status, calls, out, _ = self.run_script({'BETA_VERSION_CODE': '42', 'SUPABASE_ACCESS_TOKEN': 'secreto'}, [ROW])
        self.assertEqual(status, 0)
        self.assertEqual(len(calls), 2)
        self.assertIn('beta_publish_build(42)', calls[0])
        self.assertIn('where version_code = 42', calls[1])
        self.assertIn('versionCode `42`', out)

    def test_absent_row_fails_instead_of_publishing(self):
        status, calls, _, _ = self.run_script({'BETA_VERSION_CODE': '42', 'SUPABASE_ACCESS_TOKEN': 'secreto'}, [])
        self.assertNotEqual(status, 0)
        self.assertEqual(len(calls), 2)

    def test_out_of_range_never_registers(self):
        status, calls, _, _ = self.run_script({'BETA_VERSION_CODE': '0', 'SUPABASE_ACCESS_TOKEN': 'secreto'}, [ROW])
        self.assertNotEqual(status, 0)
        self.assertEqual(calls, [])


if __name__ == '__main__':
    unittest.main()
