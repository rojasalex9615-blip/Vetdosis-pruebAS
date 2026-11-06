"""Register a verified APK publication once. Never changes its original expiry."""
import os
import sys
from identity_schema import query

RANGE_ERROR = 'Versión fuera del rango aprobado.'
MISSING_SECRET = (
    'OMITIDO: falta SUPABASE_ACCESS_TOKEN, no se registró la publicación '
    'beta de la versión {code}. El APK queda sin registrar y, con la '
    'puerta beta activa, solo permitiría lectura y exportación.'
)
# El APK ya se subió como artefacto en un paso anterior, y el trabajo termina en
# verde. Un aviso en el registro no se ve: quien baje el APK de la página de la
# ejecución tiene que encontrar ahí mismo que esa versión no quedó registrada,
# o lo instalará creyendo que puede escribir.
UNREGISTERED_SUMMARY = (
    '### APK beta {code} SIN REGISTRAR\n\n'
    'No había `SUPABASE_ACCESS_TOKEN`, así que la versión no se registró en '
    '`beta_builds`. El APK de esta ejecución sirve para probar la interfaz, '
    'pero con la puerta beta activa solo permite lectura y exportación: no '
    'uses esta compilación para cargar datos.\n'
)


def note_missing_secret(code):
    """Deja constancia del APK sin registrar en el resumen de la ejecución."""
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if not summary:
        return
    with open(summary, 'a') as destination:
        destination.write(UNREGISTERED_SUMMARY.format(code=code))


def read_back(code):
    """Devuelve la fila registrada o None; un registro sin fila no es un registro."""
    rows = query(
        'select version_code, released_at, expires_at from private.beta_builds '
        f"where version_code = {code} and channel = 'beta'"
    )
    return rows[0] if rows else None


def main():
    code = int(os.environ['BETA_VERSION_CODE'])
    if not 1 <= code <= 2100000000:
        raise SystemExit(RANGE_ERROR)

    # Sin el secreto no hay nada que registrar: eso es una configuración ausente,
    # no un fallo del registro, y no debe marcar en rojo un APK ya verificado. Un
    # registro que sí se intenta y falla sí debe fallar, porque un build sin
    # registrar queda en modo read_export y no puede escribir (09B_beta_gate.sql).
    if not os.environ.get('SUPABASE_ACCESS_TOKEN', '').strip():
        print(MISSING_SECRET.format(code=code), file=sys.stderr)
        note_missing_secret(code)
        return 0

    query(f'select private.beta_publish_build({code})')
    build = read_back(code)
    if build is None:
        raise SystemExit(
            f'La versión {code} no quedó registrada en private.beta_builds; '
            'no se debe publicar una descarga que el servidor no reconoce.'
        )
    print(
        f'- Publicación beta registrada: versionCode `{build["version_code"]}`, '
        f'publicada `{build["released_at"]}`, caduca `{build["expires_at"]}` '
        '(ventana de 90 días desde el servidor).'
    )
    return 0


if __name__ == '__main__':
    sys.exit(main())
