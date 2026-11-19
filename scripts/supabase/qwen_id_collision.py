"""Repara las colisiones de identificadores del catálogo Qwen (migración 17A).

La credencial de Management API se lee, por orden: la variable
SUPABASE_ACCESS_TOKEN, o un archivo cuyo contenido sea el token (ruta en
SUPABASE_ACCESS_TOKEN_FILE, o el archivo por defecto
~/.config/supabase/access_token). Nunca se pasa por argumentos de línea de
comandos ni se registra. Por defecto solo inspecciona (lectura).

El problema: los lotes de Qwen se numeraron por separado y al fusionarse
chocaron. F094 designa a la vez Propofol (4-8 mg/kg IV) y Omeprazol
(0.5-1 mg/kg PO); D103 y D114 también están repetidos. Cruzar por
id_farmaco_original devuelve dos moléculas, así que ninguna dosis de esos
bloques es fiable hasta renumerar.

Uso:
  python3 scripts/supabase/qwen_id_collision.py            # inspección
  QWEN_FIX_CONFIRMATION=REPARAR_IDS_QWEN \\
    QWEN_FIX_ACTION=apply python3 scripts/supabase/qwen_id_collision.py

No valida ninguna dosis ni activa reglas de cálculo: solo deja los
identificadores sin ambigüedad.
"""
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.request

PROJECT = 'wtrelwtztkddfktrfdpb'
ENDPOINT = f'https://api.supabase.com/v1/projects/{PROJECT}/database/query'
ROOT = Path(__file__).resolve().parents[2]
MIGRATION = ROOT / 'supabase/proposed/17A_qwen_id_collision_fix.sql'
CONFIRMATION = 'REPARAR_IDS_QWEN'
DEFAULT_TOKEN_FILE = Path(os.path.expanduser('~/.config/supabase/access_token'))

PREFLIGHT = """
select
  (select count(*) from (select id_farmaco_original
     from private.vetdosis_qwen_farmacos_revision
    group by 1 having count(*) > 1) z) as farmacos_colisionados,
  (select count(*) from (select id_dosis_original
     from private.vetdosis_qwen_dosis_revision
    group by 1 having count(*) > 1) z) as dosis_colisionadas,
  (select count(*) from private.vetdosis_qwen_farmacos_revision) as farmacos,
  (select count(*) from private.vetdosis_qwen_dosis_revision) as dosis,
  (select count(*) from private.vetdosis_qwen_dosis_revision d
    where not exists (select 1 from private.vetdosis_qwen_farmacos_revision f
                       where f.id_farmaco_original = d.id_farmaco_original)) as dosis_huerfanas,
  (select count(*) from private.vetdosis_qwen_farmacos_revision
    where id_farmaco_original between 'F123' and 'F130') as rango_libre_ocupado
"""

# Estado esperado tras 17A: sin colisiones, sin huérfanas, con los ocho
# identificadores nuevos presentes.
POSTCHECK = """
select
  (select count(*) from (select id_farmaco_original
     from private.vetdosis_qwen_farmacos_revision
    group by 1 having count(*) > 1) z) as farmacos_colisionados,
  (select count(*) from (select id_dosis_original
     from private.vetdosis_qwen_dosis_revision
    group by 1 having count(*) > 1) z) as dosis_colisionadas,
  (select count(*) from private.vetdosis_qwen_farmacos_revision
    where id_farmaco_original between 'F123' and 'F130') as renumerados,
  (select count(*) from private.vetdosis_qwen_farmacos_revision
    where principio_activo in ('Propofol','Omeprazol')) as moleculas_separadas,
  (select count(*) from private.vetdosis_qwen_dosis_revision
    where id_dosis_original in ('D203','D204')) as dosis_renumeradas
"""


def access_token():
    """Token de Management API: archivo o variable de entorno. No se registra."""
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
        raise SystemExit(
            f'Supabase rechazó la operación administrativa (HTTP {error.code}). '
            'No se muestran credenciales ni respuesta privada.') from None
    except (urllib.error.URLError, TimeoutError):
        raise SystemExit(
            'No se pudo confirmar la conexión administrativa. '
            'Revisar el estado antes de reintentar.') from None


def main():
    mode = os.environ.get('QWEN_FIX_ACTION', 'inspect')
    if mode not in ('inspect', 'apply'):
        raise SystemExit('Acción desconocida; solo inspect o apply.')

    state = query(PREFLIGHT)[0]
    print('Proyecto de pruebas:', PROJECT)
    print('Preflight:', json.dumps(state, sort_keys=True))

    if mode == 'inspect':
        if state['farmacos_colisionados']:
            print(f"Colisiones detectadas: {state['farmacos_colisionados']} fármacos, "
                  f"{state['dosis_colisionadas']} dosis. Aplicar con QWEN_FIX_ACTION=apply.")
        else:
            print('Sin colisiones: nada que reparar.')
        return

    if os.environ.get('QWEN_FIX_CONFIRMATION') != CONFIRMATION:
        raise SystemExit('Falta la confirmación exacta del proyecto de pruebas.')
    if not state['farmacos_colisionados']:
        raise SystemExit('No hay colisiones que reparar; no se aplicó nada.')
    if state['rango_libre_ocupado']:
        raise SystemExit('El rango F123..F130 ya está ocupado; revisar antes de renumerar.')

    query(MIGRATION.read_text(encoding='utf-8'))

    after = query(POSTCHECK)[0]
    print('Postcheck:', json.dumps(after, sort_keys=True))
    if (after['farmacos_colisionados'] or after['dosis_colisionadas']
            or after['renumerados'] != 8 or after['dosis_renumeradas'] != 2):
        raise SystemExit('Verificación incompleta; revisar el servidor antes de reintentar.')
    print('Identificadores reparados: 8 fármacos (F123..F130) y 2 dosis (D203, D204).')
    print('Ninguna dosis queda validada: los estados de revisión no cambian.')


if __name__ == '__main__':
    main()
