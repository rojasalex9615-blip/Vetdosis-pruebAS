"""Encrypt Storage binaries for the fixed test project; never print paths or contents."""
import argparse
from datetime import datetime, timezone
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

from encrypted_database_backup import gpg_process, validate_passphrase
from identity_schema import PROJECT, query

MAX_OBJECTS = 10000
MAX_TOTAL_BYTES = 2 * 1024 * 1024 * 1024
SQL = "select bucket_id,name,id,updated_at from storage.objects order by bucket_id,name"


def configuration_status(environment):
    key = environment.get('SUPABASE_TEST_STORAGE_SERVICE_ROLE_KEY', '')
    phrase = environment.get('SUPABASE_TEST_BACKUP_PASSPHRASE', '')
    token = environment.get('SUPABASE_ACCESS_TOKEN', '')
    return {'management_token_present': bool(token),
            'storage_key_present': len(key) >= 20,
            'backup_passphrase_present': bool(phrase),
            'configuration_valid': bool(token and 20 <= len(phrase) <= 1000
                                        and '\n' not in phrase and '\r' not in phrase)}


def resolve_storage_key(environment, opener=urlopen):
    direct = environment.get('SUPABASE_TEST_STORAGE_SERVICE_ROLE_KEY', '')
    if len(direct) >= 20:
        return direct
    token = environment.get('SUPABASE_ACCESS_TOKEN', '')
    if not token:
        raise ValueError('Management access token is missing.')
    request = Request(f'https://api.supabase.com/v1/projects/{PROJECT}/api-keys?reveal=true',
                      headers={'Authorization': f'Bearer {token}'})
    try:
        with opener(request, timeout=30) as response:
            keys = json.load(response)
    except (HTTPError, URLError, TimeoutError, ValueError):
        raise ValueError('Storage key lookup unavailable.') from None
    if not isinstance(keys, list):
        raise ValueError('Storage key lookup incomplete.')
    candidates = [row['api_key'] for row in keys if isinstance(row, dict)
                  and row.get('type') == 'secret' and row.get('name') == 'default'
                  and isinstance(row.get('api_key'), str)
                  and row['api_key'].startswith('sb_secret_')]
    if len(candidates) != 1:
        raise ValueError('A unique default Storage secret key is required.')
    return candidates[0]


def object_inventory(read=query):
    rows = read(SQL)
    if not isinstance(rows, list) or len(rows) > MAX_OBJECTS:
        raise ValueError('Storage inventory exceeded configured limits.')
    seen = set()
    for row in rows:
        if not isinstance(row, dict) or set(row) != {'bucket_id', 'name', 'id', 'updated_at'}:
            raise ValueError('Invalid Storage inventory response.')
        bucket, name = row['bucket_id'], row['name']
        if (not isinstance(bucket, str) or not bucket or not isinstance(name, str) or not name
                or not isinstance(row['id'], str) or not row['id']
                or not isinstance(row['updated_at'], str) or not row['updated_at']):
            raise ValueError('Invalid Storage inventory row.')
        if (bucket, name) in seen:
            raise ValueError('Duplicate Storage inventory row.')
        seen.add((bucket, name))
    return rows


def download_object(bucket, name, key, opener=urlopen):
    endpoint = (f'https://{PROJECT}.supabase.co/storage/v1/object/authenticated/'
                f'{quote(bucket, safe="")}/{quote(name, safe="/")}')
    request = Request(endpoint, headers={'Authorization': f'Bearer {key}', 'apikey': key})
    return opener(request, timeout=60)


def _sha256_file(file):
    digest = hashlib.sha256()
    file.seek(0)
    while chunk := file.read(1024 * 1024):
        digest.update(chunk)
    file.seek(0)
    return digest.hexdigest()


def create_backup(output_dir, key, passphrase, rows, opener=urlopen, inventory_check=None):
    validate_passphrase(passphrase)
    if len(key) < 20:
        raise ValueError('Storage service role key is missing.')
    output_dir = Path(output_dir)
    output_dir.mkdir(mode=0o700, parents=True, exist_ok=False)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    target = output_dir / f'vetdosis-storage-{stamp}.tar.gpg'
    entries = []
    total_bytes = 0
    with tempfile.TemporaryDirectory(prefix='vetdosis-storage-') as temporary:
        home = Path(temporary) / 'gpg'
        home.mkdir(mode=0o700)
        try:
            with tempfile.TemporaryFile() as errors:
                with gpg_process(home, passphrase,
                                 ['--symmetric', '--cipher-algo', 'AES256',
                                  '--s2k-mode', '3', '--s2k-count', '65011712',
                                  '--compress-algo', 'none', '--output', str(target)],
                                 stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                                 stderr=errors) as encryptor:
                    with tarfile.open(fileobj=encryptor.stdin, mode='w|') as archive:
                        for index, row in enumerate(rows):
                            with tempfile.TemporaryFile() as file:
                                with download_object(row['bucket_id'], row['name'], key, opener) as response:
                                    while chunk := response.read(1024 * 1024):
                                        total_bytes += len(chunk)
                                        if total_bytes > MAX_TOTAL_BYTES:
                                            raise ValueError('Storage backup exceeded configured size limit.')
                                        file.write(chunk)
                                size = file.tell()
                                digest = _sha256_file(file)
                                member_name = f'objects/{index:08d}.bin'
                                member = tarfile.TarInfo(member_name)
                                member.size = size
                                member.mode = 0o600
                                archive.addfile(member, file)
                                entries.append({'member': member_name,
                                                'bucket': row['bucket_id'], 'name': row['name'],
                                                'bytes': size, 'sha256': digest})
                        contents = json.dumps({'format': 'vetdosis-storage-v1',
                                               'project_ref': PROJECT,
                                               'objects': entries}, ensure_ascii=False).encode()
                        manifest = tarfile.TarInfo('manifest.json')
                        manifest.size = len(contents)
                        manifest.mode = 0o600
                        archive.addfile(manifest, io.BytesIO(contents))
                    encryptor.stdin.close()
                    if encryptor.wait() != 0:
                        raise RuntimeError('Storage encryption failed.')
                target.chmod(0o600)
                with tempfile.TemporaryFile() as plaintext:
                    with gpg_process(home, passphrase, ['--decrypt', str(target)],
                                     stdout=subprocess.PIPE, stderr=errors) as decryptor:
                        while chunk := decryptor.stdout.read(1024 * 1024):
                            plaintext.write(chunk)
                        decryptor.stdout.close()
                        if decryptor.wait() != 0:
                            raise RuntimeError('Storage decryption failed.')
                    plaintext.seek(0)
                    with tarfile.open(fileobj=plaintext, mode='r:*') as archive:
                        actual = []
                        for entry in entries:
                            member = archive.next()
                            if not member or not member.isfile() or member.name != entry['member']:
                                raise RuntimeError('Storage archive member mismatch.')
                            source = archive.extractfile(member)
                            digest = hashlib.sha256()
                            count = 0
                            while chunk := source.read(1024 * 1024):
                                count += len(chunk)
                                digest.update(chunk)
                            if count != entry['bytes'] or digest.hexdigest() != entry['sha256']:
                                raise RuntimeError('Storage archive hash mismatch.')
                            actual.append(member.name)
                        manifest = archive.next()
                        if not manifest or manifest.name != 'manifest.json' or archive.next():
                            raise RuntimeError('Storage archive manifest mismatch.')
                        embedded = json.load(archive.extractfile(manifest))
                        if embedded != {'format': 'vetdosis-storage-v1',
                                       'project_ref': PROJECT, 'objects': entries}:
                            raise RuntimeError('Storage archive manifest mismatch.')
                if inventory_check is not None and inventory_check() != rows:
                    raise RuntimeError('Storage inventory changed during export.')
        except BaseException:
            target.unlink(missing_ok=True)
            raise
        finally:
            subprocess.run(['gpgconf', '--homedir', str(home), '--kill', 'gpg-agent'],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    with target.open('rb') as encrypted_file:
        encrypted = _sha256_file(encrypted_file)
    public_manifest = {'project_ref': PROJECT, 'created_at_utc': stamp,
                       'format': 'encrypted Storage archive v1', 'file': target.name,
                       'objects': len(entries), 'plaintext_object_bytes': total_bytes,
                       'encrypted_sha256': encrypted,
                       'binary_integrity_verified': True,
                       'scope': 'Storage binaries only. Database metadata is backed up separately; '
                                'the two exports do not share a transaction snapshot.'}
    (output_dir / 'manifest.json').write_text(json.dumps(public_manifest, indent=2) + '\n')
    return public_manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-config', action='store_true')
    parser.add_argument('--output-dir', type=Path)
    args = parser.parse_args()
    status = configuration_status(os.environ)
    if args.check_config:
        try:
            status['storage_key_resolvable'] = bool(resolve_storage_key(os.environ))
        except ValueError:
            status['storage_key_resolvable'] = False
        status['configuration_valid'] = status['configuration_valid'] and status['storage_key_resolvable']
        print(json.dumps(status, indent=2))
        return
    if not status['configuration_valid'] or args.output_dir is None:
        raise SystemExit('Configure management access token and backup passphrase in GitHub secrets; never send them in chat.')
    try:
        key = resolve_storage_key(os.environ)
        rows = object_inventory()
        result = create_backup(args.output_dir, key,
                               os.environ['SUPABASE_TEST_BACKUP_PASSPHRASE'], rows,
                               inventory_check=object_inventory)
        print(json.dumps({key: result[key] for key in ('project_ref','objects','plaintext_object_bytes',
                                                        'binary_integrity_verified')}))
    except (ValueError, RuntimeError, OSError, KeyError, TypeError):
        raise SystemExit('Storage backup failed safely; no paths, contents or credentials are logged.') from None


if __name__ == '__main__':
    main()
