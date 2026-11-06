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
    aviso = (
        'OMITIDO: falta SUPABASE_ACCESS_TOKEN, no se registró la publicación '
        f'beta de la versión {code}. El APK queda sin registrar y, con la '
        'puerta beta activa, solo permitiría lectura y exportación.'
    )
    print(aviso, file=sys.stderr)
    # El APK ya se subió como artefacto en un paso anterior, y el trabajo
    # termina en verde. Un aviso en el registro no se ve: quien baje el APK de
    # la página de la ejecución tiene que encontrar ahí mismo que esa versión
    # no quedó registrada, o lo instalará creyendo que puede escribir.
    resumen = os.environ.get('GITHUB_STEP_SUMMARY')
    if resumen:
        with open(resumen, 'a') as destino:
            destino.write(
                f'### APK beta {code} SIN REGISTRAR\n\n'
                'No había `SUPABASE_ACCESS_TOKEN`, así que la versión no se '
                'registró en `beta_builds`. El APK de esta ejecución sirve '
                'para probar la interfaz, pero con la puerta beta activa solo '
                'permite lectura y exportación: no uses esta compilación para '
                'cargar datos.\n'
            )
    raise SystemExit(0)

query(f'select private.beta_publish_build({code})')
print('Publicación beta registrada con hora de servidor y caducidad de 90 días.')
