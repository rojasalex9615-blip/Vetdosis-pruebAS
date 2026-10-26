import io
import json
from pathlib import Path
import tempfile
import unittest

from encrypted_storage_backup import (
    configuration_status, create_backup, object_inventory, resolve_storage_key,
)
from verify_storage_backup import verify_backup


class StorageBackupTest(unittest.TestCase):
    def test_configuration_requires_management_token_and_passphrase(self):
        self.assertFalse(configuration_status({})['configuration_valid'])
        self.assertTrue(configuration_status({
            'SUPABASE_ACCESS_TOKEN': 'synthetic-management-token',
            'SUPABASE_TEST_BACKUP_PASSPHRASE': 'synthetic-test-passphrase-123',
        })['configuration_valid'])

    def test_storage_key_is_fetched_without_logging_or_selecting_publishable_keys(self):
        def opener(_request, timeout):
            return io.BytesIO(json.dumps([
                {'name': 'default', 'type': 'publishable', 'api_key': 'sb_publishable_wrong'},
                {'name': 'default', 'type': 'secret', 'api_key': 'sb_secret_synthetic'},
            ]).encode())
        self.assertEqual(resolve_storage_key({'SUPABASE_ACCESS_TOKEN': 'synthetic'}, opener),
                         'sb_secret_synthetic')

    def test_inventory_rejects_duplicates_and_unexpected_fields(self):
        rows = [{'bucket_id': 'private', 'name': 'one.png', 'id': 'synthetic-id',
                 'updated_at': '2026-10-25T09:00:00Z'}]
        self.assertEqual(object_inventory(lambda _: rows), rows)
        with self.assertRaises(ValueError):
            object_inventory(lambda _: rows + rows)
        with self.assertRaises(ValueError):
            object_inventory(lambda _: [{'bucket_id': 'private', 'name': 'one.png', 'owner': 'secret'}])

    def test_real_encryption_and_recovery_check_cover_every_binary(self):
        rows = [{'bucket_id': 'private', 'name': 'folder/patient-note.png',
                 'id': 'synthetic-1', 'updated_at': '2026-10-25T09:00:00Z'},
                {'bucket_id': 'other', 'name': 'blank.bin',
                 'id': 'synthetic-2', 'updated_at': '2026-10-25T09:00:00Z'}]
        bodies = [b'synthetic image bytes', b'']
        calls = []

        def opener(request, timeout):
            calls.append(request.full_url)
            return io.BytesIO(bodies[len(calls)-1])

        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'encrypted'
            result = create_backup(output, 'synthetic-service-role-key-123',
                                   'synthetic-test-passphrase-123', rows, opener,
                                   inventory_check=lambda: rows)
            self.assertEqual(result['objects'], 2)
            self.assertEqual(result['plaintext_object_bytes'], len(bodies[0]))
            self.assertTrue(result['binary_integrity_verified'])
            self.assertEqual(len(list(output.glob('*.tar.gpg'))), 1)
            self.assertNotIn('patient-note', (output / 'manifest.json').read_text())
            self.assertNotIn('synthetic image', (output / 'manifest.json').read_text())
            self.assertEqual(json.loads((output / 'manifest.json').read_text())['objects'], 2)
            recovered = verify_backup(output, 'synthetic-test-passphrase-123')
            self.assertTrue(recovered['isolated_binary_recovery_verified'])
            self.assertEqual(recovered['objects'], 2)
            self.assertNotIn('object_keys', recovered)
            private_mapping = verify_backup(output, 'synthetic-test-passphrase-123',
                                            include_object_keys=True)
            self.assertEqual(private_mapping['object_keys'],
                             [('private', 'folder/patient-note.png'), ('other', 'blank.bin')])
        self.assertEqual(len(calls), 2)

    def test_changed_inventory_cannot_publish_a_complete_backup(self):
        rows = [{'bucket_id': 'private', 'name': 'one.bin',
                 'id': 'synthetic-1', 'updated_at': '2026-10-25T09:00:00Z'}]
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'encrypted'
            with self.assertRaises(RuntimeError):
                create_backup(output, 'synthetic-service-role-key-123',
                              'synthetic-test-passphrase-123', rows,
                              opener=lambda *_args, **_kwargs: io.BytesIO(b'original'),
                              inventory_check=lambda: [])
            self.assertFalse(list(output.glob('*.tar.gpg')))

    def test_isolated_restore_rejects_changed_encrypted_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'encrypted'
            create_backup(output, 'synthetic-service-role-key-123',
                          'synthetic-test-passphrase-123', [])
            encrypted = next(output.glob('*.tar.gpg'))
            with encrypted.open('ab') as file:
                file.write(b'changed')
            with self.assertRaises(ValueError):
                verify_backup(output, 'synthetic-test-passphrase-123')


if __name__ == '__main__':
    unittest.main()
