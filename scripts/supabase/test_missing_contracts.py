import copy
import unittest
from missing_contracts import bundle, plan, PROJECT, SOURCES, INDEX_SOURCES, MISSING_RPCS


def catalog():
    from pathlib import Path
    import json
    result=json.loads((Path(__file__).resolve().parents[2]/'review/supabase-missing-contracts-20261028/catalog-pruebas.json').read_text())
    result['profile']='synthetic-local'
    return result


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
        self.assertEqual(next(f for f in manifest['existing_functions'] if f['name']=='clinic_export')['signature'], 'public.clinic_export(uuid)')
        for text in ['md5(prosrc)', 'pg_get_function_result(oid)', 'proargnames',
                     'proconfig', "has_function_privilege('anon'", 'prosecdef']:
            self.assertIn(text,sql)
        changed=copy.deepcopy(original);changed['functions'][0]['arg_names']=['different']
        self.assertNotEqual(bundle(changed)[0],sql)

    def test_all_fifteen_fingerprints_required_for_either_variant(self):
        for commit in (False,True):
            for index in range(15):
                c=catalog();c['profile']='observed-test-catalog'
                c['functions'].pop(index)
                with self.assertRaisesRegex(ValueError,'fingerprint set'): bundle(c,commit=commit)
        c=catalog();c['functions'].append(copy.deepcopy(c['functions'][0]))
        with self.assertRaisesRegex(ValueError,'fingerprint set'): bundle(c)

    def test_target_identity_is_required_and_checked_in_generated_sql(self):
        for identity in ({},{'database':'other','database_oid':'5','system_identifier':'123'}):
            c=catalog();c['target_identity']=identity
            with self.assertRaises(ValueError): bundle(c)
        sql,_=bundle(catalog())
        self.assertLess(sql.index('upgrade_target_identity_mismatch'),sql.index('-- Source:'))
        self.assertIn('pg_control_system()',sql)
        self.assertIn('current_database()',sql)

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
