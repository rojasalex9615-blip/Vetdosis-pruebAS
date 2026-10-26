"""Verify a published encrypted Storage artifact without accessing the live project."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile

from encrypted_database_backup import gpg_process, validate_passphrase
from encrypted_storage_backup import _sha256_file
from identity_schema import PROJECT


def verify_backup(directory, passphrase, *, include_object_keys=False):
    validate_passphrase(passphrase)
    directory = Path(directory)
    manifest = json.loads((directory / 'manifest.json').read_text())
    name = manifest.get('file')
    if (manifest.get('project_ref') != PROJECT or
            not isinstance(name, str) or Path(name).name != name or
            not name.endswith('.tar.gpg') or
            type(manifest.get('objects')) is not int or manifest['objects'] < 0):
        raise ValueError('Invalid Storage backup manifest.')
    archive_file = directory / name
    with archive_file.open('rb') as source:
        if _sha256_file(source) != manifest.get('encrypted_sha256'):
            raise ValueError('Encrypted Storage archive hash mismatch.')
    with tempfile.TemporaryDirectory(prefix='vetdosis-storage-restore-') as temporary:
        home = Path(temporary) / 'gpg'
        home.mkdir(mode=0o700)
        try:
            with tempfile.TemporaryFile() as errors, tempfile.TemporaryFile() as plaintext:
                with gpg_process(home, passphrase, ['--decrypt', str(archive_file)],
                                 stdout=subprocess.PIPE, stderr=errors) as decryptor:
                    while chunk := decryptor.stdout.read(1024 * 1024):
                        plaintext.write(chunk)
                    decryptor.stdout.close()
                    if decryptor.wait() != 0:
                        raise RuntimeError('Storage archive could not be decrypted.')
                plaintext.seek(0)
                with tarfile.open(fileobj=plaintext, mode='r:*') as archive:
                    actual = []
                    while True:
                        member = archive.next()
                        if not member or member.name == 'manifest.json':
                            break
                        expected_name = f'objects/{len(actual):08d}.bin'
                        if not member.isfile() or member.name != expected_name:
                            raise ValueError('Invalid Storage archive member.')
                        source = archive.extractfile(member)
                        digest = hashlib.sha256()
                        size = 0
                        while chunk := source.read(1024 * 1024):
                            size += len(chunk)
                            digest.update(chunk)
                        actual.append({'member': member.name, 'bytes': size,
                                       'sha256': digest.hexdigest()})
                    if not member or not member.isfile() or archive.next():
                        raise ValueError('Invalid Storage archive manifest.')
                    embedded = json.load(archive.extractfile(member))
                    if (embedded.get('format') != 'vetdosis-storage-v1' or
                            embedded.get('project_ref') != PROJECT or
                            not isinstance(embedded.get('objects'), list) or
                            len(embedded['objects']) != len(actual)):
                        raise ValueError('Invalid Storage archive manifest.')
                    for expected, observed in zip(embedded['objects'], actual):
                        if (not isinstance(expected, dict) or
                                not isinstance(expected.get('bucket'), str) or
                                not isinstance(expected.get('name'), str) or
                                any(expected.get(key) != observed[key]
                                    for key in ('member', 'bytes', 'sha256'))):
                            raise ValueError('Storage archive object hash mismatch.')
        finally:
            subprocess.run(['gpgconf', '--homedir', str(home), '--kill', 'gpg-agent'],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    total = sum(item['bytes'] for item in actual)
    if (len(actual) != manifest['objects'] or
            total != manifest.get('plaintext_object_bytes')):
        raise ValueError('Storage backup counts do not match.')
    result = {'project_ref': PROJECT, 'objects': len(actual),
            'plaintext_object_bytes': total, 'isolated_binary_recovery_verified': True,
            'active_project_modified': False}
    if include_object_keys:
        keys = [(entry['bucket'], entry['name']) for entry in embedded['objects']]
        if len(set(keys)) != len(keys):
            raise ValueError('Duplicate Storage archive object identity.')
        result['object_keys'] = keys  # Private process memory; never print this result.
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifact-dir', type=Path, required=True)
    args = parser.parse_args()
    try:
        result = verify_backup(args.artifact_dir,
                               os.environ.get('SUPABASE_TEST_BACKUP_PASSPHRASE', ''))
    except (ValueError, RuntimeError, OSError, KeyError, TypeError, tarfile.TarError):
        raise SystemExit('Isolated Storage recovery failed safely; no paths or contents are logged.') from None
    print(json.dumps(result))


if __name__ == '__main__':
    main()
