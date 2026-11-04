"""Compare verified Storage binaries with metadata in an isolated database restore."""
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import subprocess
import tarfile

from encrypted_database_backup import validate_passphrase
from identity_schema import PROJECT
from restore_database_backup_isolated import run_restore
from verify_storage_backup import verify_backup


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--database-artifact-dir', type=Path, required=True)
    parser.add_argument('--storage-artifact-dir', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if any(os.environ.get(name) for name in (
            'SUPABASE_TEST_DB_URL', 'SUPABASE_ACCESS_TOKEN',
            'SUPABASE_TEST_STORAGE_SERVICE_ROLE_KEY')):
        raise SystemExit('Live Supabase credentials are forbidden in isolated recovery.')
    try:
        passphrase = os.environ.get('SUPABASE_TEST_BACKUP_PASSPHRASE', '')
        validate_passphrase(passphrase)
        database_manifest = json.loads((args.database_artifact_dir / 'manifest.json').read_text())
        storage_manifest = json.loads((args.storage_artifact_dir / 'manifest.json').read_text())
        if (database_manifest.get('project_ref') != PROJECT or
                storage_manifest.get('project_ref') != PROJECT):
            raise ValueError('Backup projects differ.')
        database_time = datetime.fromisoformat(database_manifest['created_at_utc'])
        storage_time = datetime.fromisoformat(storage_manifest['created_at_utc'])
        if database_time.tzinfo is None or storage_time.tzinfo is None:
            raise ValueError('Backup timestamps require timezones.')
        gap_seconds = abs((database_time - storage_time).total_seconds())
        if gap_seconds > 86400:
            raise ValueError('Backup artifacts are more than one day apart.')
        recovered = verify_backup(args.storage_artifact_dir, passphrase,
                                  include_object_keys=True)
        keys = recovered.pop('object_keys')
        report = run_restore(args.database_artifact_dir, passphrase, args.output,
                             storage_object_keys=keys)
        report['storage_binary_recovery_verified'] = recovered['isolated_binary_recovery_verified']
        report['backup_capture_gap_seconds'] = round(gap_seconds)
        report['joint_backup_mapping_verified'] = bool(
            report.get('archive_restore_succeeded') and
            report.get('verification_queries_passed') and
            report.get('storage_objects_match_database'))
        report['service_recovery_verified'] = False
        report['scope'] = ('Both encrypted archives were verified in an isolated job; '
                           'Storage object identities were compared with restored database metadata. '
                           'No Storage service, Auth settings, secrets or global roles were restored.')
        args.output.write_text(json.dumps(report, indent=2) + '\n')
    except (ValueError, RuntimeError, OSError, KeyError, TypeError, tarfile.TarError,
            subprocess.SubprocessError):
        raise SystemExit('Joint backup verification failed safely; no private details are logged.') from None
    print(json.dumps(report, indent=2))
    if not report['joint_backup_mapping_verified']:
        raise SystemExit('The two backups do not form a verified matching pair.')


if __name__ == '__main__':
    main()
