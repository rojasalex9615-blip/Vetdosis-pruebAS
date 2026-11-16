"""Aplica la ingesta de pautas de Grok en el proyecto de pruebas fijo.

La credencial de Management API se lee, por orden: la variable
SUPABASE_ACCESS_TOKEN, o un archivo cuyo contenido sea el token (ruta en
SUPABASE_ACCESS_TOKEN_FILE, o el archivo por defecto
~/.config/supabase/access_token). Nunca se pasa por argumentos de línea de
comandos ni se registra. Por defecto solo inspecciona (lectura).

Aplica dos migraciones candidatas, ambas idempotentes:
  15P · ingesta verbatim de las 1197 pautas (review_state='pending')
  15Q · RPC review_pauta_list para el modo revisión

No activa ninguna regla de cálculo: las pautas entran como pendientes de revisión.
"""
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.request

PROJECT = 'wtrelwtztkddfktrfdpb'
BATCH = '7e4c1a92-3b5d-4f81-9a26-8c1d2e5f6a70'
ENDPOINT = f'https://api.supabase.com/v1/projects/{PROJECT}/database/query'
ROOT = Path(__file__).resolve().parents[2]
CONFIRMATION = 'ACTIVAR_PAUTAS_EN_PRUEBAS'
DEFAULT_TOKEN_FILE = Path(os.path.expanduser('~/.config/supabase/access_token'))
PREFLIGHT = f"""select
 to_regclass('vetdosis_reference_staging.raw_intake_rows') is not null as staging_ready,
 to_regclass('vetdosis_reference_staging.import_batches') is not null as batches_ready,
 to_regprocedure('private.has_clinic_role(uuid,text[])') is not null as permission_ready,
 to_regprocedure('public.review_pauta_list(uuid,text,integer,integer)') is not null as review_fn_exists,
 exists(select 1 from vetdosis_reference_staging.import_batches where id='{BATCH}') as batch_present,
 (select count(*) from vetdosis_reference_staging.raw_intake_rows
   where source_filename='Pautas_VetDosis_MAESTRO.csv') as pauta_rows"""


def access_token():
    """Token de Management API: archivo o variable de entorno. No se registra.

    El archivo tiene prioridad para poder usar un token subido a mano aunque el
    entorno traiga uno caducado.
    """
    token_file = Path(os.environ.get('SUPABASE_ACCESS_TOKEN_FILE', DEFAULT_TOKEN_FILE))
    if token_file.exists():
        content = token_file.read_text(encoding='utf-8').strip()
        if content.startswith('{'):
            content = json.loads(content).get('access_token', '').strip()
        if content:
            return content
    token = os.environ.get('SUPABASE_ACCESS_TOKEN', '').strip()
    if token:
        return token
    raise SystemExit(
        'Falta el token de Management API. Define SUPABASE_ACCESS_TOKEN, o deja '
        f'el token en {token_file} (o en SUPABASE_ACCESS_TOKEN_FILE).')


def query(sql):
    token = access_token()
    request = urllib.request.Request(
        ENDPOINT,
        data=json.dumps({'query': sql}).encode(),
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
        method='POST',
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        raise SystemExit(f'Supabase rechazó la operación administrativa (HTTP {error.code}). No se muestran credenciales ni respuesta privada.') from None
    except (urllib.error.URLError, TimeoutError):
        raise SystemExit('No se pudo confirmar la conexión administrativa. Revisar el estado antes de reintentar.') from None


def main():
    mode = os.environ.get('PAUTAS_ACTION', 'inspect')
    if mode not in ('inspect', 'apply'):
        raise SystemExit('Acción desconocida; solo inspect o apply.')
    state = query(PREFLIGHT)[0]
    print('Proyecto de pruebas:', PROJECT)
    print('Preflight:', json.dumps(state, sort_keys=True))
    if mode == 'inspect':
        return
    if os.environ.get('PAUTAS_CONFIRMATION') != CONFIRMATION:
        raise SystemExit('Falta la confirmación exacta del proyecto de pruebas.')
    if not state['staging_ready'] or not state['batches_ready']:
        raise SystemExit('Falta el esquema de preparación (vetdosis_reference_staging); no se aplicó nada.')
    if not state['permission_ready']:
        raise SystemExit('Falta private.has_clinic_role; no se aplicó nada.')

    intake = (ROOT / 'supabase/proposed/15P_pautas_grok_1197_intake.sql').read_text()
    query(intake)
    read = (ROOT / 'supabase/proposed/15Q_pauta_review_read.sql').read_text()
    query(read)

    after = query(PREFLIGHT)[0]
    if not after['batch_present'] or not after['review_fn_exists'] or int(after['pauta_rows']) < 1197:
        raise SystemExit('Verificación incompleta; revisar el servidor antes de reintentar.')
    print(f"Pautas aplicadas: lote {BATCH}, {after['pauta_rows']} filas, RPC review_pauta_list disponible.")
    print('Ninguna pauta queda activa para cálculo: todas entran con review_state pending.')


if __name__ == '__main__':
    main()
