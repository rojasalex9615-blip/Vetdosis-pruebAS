"""Register a verified APK publication once. Never changes its original expiry."""
import os
import sys
from identity_schema import query

RANGE_ERROR = 'Versión fuera del rango aprobado.'
NO_TOKEN_NOTICE = (
    'OMITIDO: falta SUPABASE_ACCESS_TOKEN, no se registró la publicación '
    'beta de la versión {code}. El APK queda sin registrar y, con la '
    'puerta beta activa, solo permitiría lectura y exportación.'
)


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
        print(NO_TOKEN_NOTICE.format(code=code), file=sys.stderr)
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
