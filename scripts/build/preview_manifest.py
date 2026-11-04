"""Record exact preview provenance; fail closed for missing integration sources."""
import json
import os
from pathlib import Path
import subprocess


def main():
    sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    if sha != os.environ['GITHUB_SHA']:
        raise SystemExit('Checkout does not match workflow commit')
    modules = {
        'manufacturer_catalog': 'assets/clinical/manufacturer_research.v1.json',
        'manufacturer_calculator': 'lib/modules/doses/presentation/commercial_package_dose_screen.dart',
        'settings': 'lib/modules/clinic_experience/presentation/clinic_experience_screen.dart',
        'navigation': 'lib/modules/core/domain/section_catalog.dart',
        'launcher': 'android/app/src/main/res/mipmap-anydpi/vetdosis_launcher.xml',
        'hospital_push': 'lib/modules/hospital/application/hospital_push_service.dart',
        'service_commissions': 'lib/modules/operations/presentation/service_commission_panel.dart',
        'storage_backup': 'scripts/supabase/encrypted_storage_backup.py',
    }
    for name, path in modules.items():
        if not Path(path).is_file():
            raise SystemExit(f'Missing integration module: {name}: {path}')
    output = Path('build/preview')
    output.mkdir(parents=True, exist_ok=True)
    manufacturer = json.loads(Path(modules['manufacturer_catalog']).read_text())
    manifest = {
        'manufacturer_research': {
            'source_sha256': manufacturer['source_sha256'],
            'products': len(manufacturer['products']),
            'reports': len(manufacturer['reports']),
        },
        'source_repository': os.environ['GITHUB_REPOSITORY'],
        'source_sha': sha,
        'integration_sha': sha,
        'source_sol': 'rojasalex9615-blip/Vet-dosis-pruebas@b64ff80ca84bff29977f747c6052848da5103ad6',
        'modules_present': modules,
        'workflow_run': f"https://github.com/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}",
        'type': 'debug-preview-not-for-distribution',
        'clinical_validation_complete': False,
    }
    (output / 'BUILD-SOURCES.json').write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    main()
