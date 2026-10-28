import copy
import unittest
from missing_contracts import bundle, plan, PROJECT, SOURCES, INDEX_SOURCES, MISSING_RPCS


def catalog():
    return {'project_ref': PROJECT, 'profile': 'synthetic-local', 'relations': [],
            'functions': [{'schema': 'public', 'name': 'clinic_export',
                           'signature': 'clinic_export(uuid)', 'source_md5': '0'*32,
                           'security_definer': True, 'anon_execute': False,
                           'authenticated_execute': True, 'arg_names': ['p_clinic'],
                           'returns': 'text', 'config': ['search_path=""']} ]}


class MissingContractTests(unittest.TestCase):
    def test_default_rehearsal_has_one_outer_transaction_and_all_sources(self):
        sql, manifest = bundle(catalog())
        self.assertTrue(sql.endswith('rollback;\n'))
        self.assertNotIn('\ncommit;', sql)
        self.assertEqual(sql.count('-- Source:'), 17)
        self.assertEqual(len(manifest['missing_rpcs']), 29)
        self.assertEqual(len(SOURCES), len(set(SOURCES)))
        self.assertNotIn('CREATE INDEX CONCURRENTLY', sql)
        self.assertEqual(len(INDEX_SOURCES), 2)

    def test_commit_is_explicit_and_refuses_synthetic_provenance(self):
        with self.assertRaises(ValueError): bundle(catalog(), commit=True)
        c = catalog(); c['profile'] = 'observed-test-catalog'
        self.assertEqual(bundle(c, commit=True)[0].removesuffix('commit;\n'),
                         bundle(c)[0].removesuffix('rollback;\n'))

    def test_unidentified_or_wrong_project_catalog_is_rejected(self):
        for key, value in [('project_ref','wrong'), ('profile',None)]:
            c = catalog(); c[key] = value
            with self.assertRaises(ValueError): plan(c)

    def test_partial_or_replayed_upgrade_is_rejected_before_generation(self):
        c = catalog()
        c['functions'].append({'schema':'public','name':MISSING_RPCS[0]})
        with self.assertRaises(ValueError): plan(c)
        c = catalog()
        c['relations'].append({'schema':'public','name':'appointment_care_records'})
        with self.assertRaises(ValueError): plan(c)

    def test_drift_guard_covers_named_arguments_return_type_search_path_and_acl(self):
        original = catalog()
        sql, manifest = bundle(original)
        self.assertEqual(manifest['existing_functions'][0]['signature'], 'public.clinic_export(uuid)')
        for text in ['md5(prosrc)', 'pg_get_function_result(oid)', 'proargnames',
                     'proconfig', "has_function_privilege('anon'", 'prosecdef']:
            self.assertIn(text,sql)
        changed=copy.deepcopy(original);changed['functions'][0]['arg_names']=['different']
        self.assertNotEqual(bundle(changed)[0],sql)

    def test_upgrade_preserves_data_and_does_not_activate_authority_or_restoration(self):
        sql, _ = bundle(catalog())
        for message in ['upgrade_changed_existing_data', 'upgrade_changed_policies',
                        'upgrade_enabled_restore_target', 'upgrade_seeded_operations',
                        'upgrade_anonymous_rpc_access', 'upgrade_already_installed_review_required']:
            self.assertIn(message,sql)
        self.assertIn('on commit drop',sql)
        self.assertIn("set local lock_timeout='5s'",sql)
        self.assertIn('backup_restore_test_targets',sql)


if __name__ == '__main__': unittest.main()
