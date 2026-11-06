"""Register a verified APK publication once. Never changes its original expiry."""
import os
import sys
from identity_schema import query

code = int(os.environ['BETA_VERSION_CODE'])
if not 1 <= code <= 2100000000:
    raise SystemExit('Versión fuera del rango aprobado.')

# Sin el secreto no hay nada que registrar: eso es una configuración ausente,
# no un fallo del registro, y no debe marcar en rojo un APK ya verificado. Un
# registro que sí se intenta y falla sí debe fallar, porque un build sin
# registrar queda en modo read_export y no puede escribir (09B_beta_gate.sql).
if not os.environ.get('SUPABASE_ACCESS_TOKEN', '').strip():
    print(
        'OMITIDO: falta SUPABASE_ACCESS_TOKEN, no se registró la publicación '
        f'beta de la versión {code}. El APK queda sin registrar y, con la '
        'puerta beta activa, solo permitiría lectura y exportación.',
        file=sys.stderr,
    )
    raise SystemExit(0)

query(f'select private.beta_publish_build({code})')
print('Publicación beta registrada con hora de servidor y caducidad de 90 días.')
