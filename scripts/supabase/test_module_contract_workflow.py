"""Keep the P0 PR workflow unable to access remote credentials or the API."""
from pathlib import Path
import re
import unittest

WORKFLOW = Path(__file__).resolve().parents[2] / '.github/workflows/audit-p0-module-contract.yml'


class WorkflowQuarantineTest(unittest.TestCase):
    def test_no_remote_job_or_credentials_on_any_event(self):
        text = WORKFLOW.read_text()
        self.assertNotIn('SUPABASE_ACCESS_TOKEN', text)
        self.assertNotIn('secrets.', text)
        self.assertNotIn('remote-readonly:', text)
        self.assertNotRegex(text, r'python3\s+scripts/supabase/module_contract_readonly\.py')
        self.assertNotIn('pull_request_target', text)

    def test_local_tests_remain_and_actions_are_immutable(self):
        text = WORKFLOW.read_text()
        self.assertIn('pull_request:', text)
        self.assertIn('test_module_contract*.py', text)
        self.assertIn('run_module_navigation_dashboard.sh', text)
        actions = re.findall(r'uses:\s*([^\s#]+)', text)
        self.assertTrue(actions)
        self.assertTrue(all(re.fullmatch(r'[^@]+@[0-9a-f]{40}', action) for action in actions))
        self.assertEqual(text.count('persist-credentials: false'), len(actions))
        self.assertIn('contents: read', text)


if __name__ == '__main__':
    unittest.main()
