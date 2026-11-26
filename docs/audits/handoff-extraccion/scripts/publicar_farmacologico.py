#!/usr/bin/env python3
"""Publica el vademécum farmacológico y genera el asset de la app.

- Recalcula la versión (hash del contenido) en public.vetdosis_farmacologico_version.
- Escribe el asset que la app lleva empaquetado.

Variables de entorno:
  SUPABASE_ACCESS_TOKEN  token de la Management API (no se escribe nunca en disco)
  SUPABASE_PROJECT       referencia del proyecto, por defecto wtrelwtztkddfktrfdpb

Uso:
  python3 publicar_farmacologico.py --asset ../../assets/clinical/farmacologico.v1.json
"""
import argparse, hashlib, json, os, sys, urllib.error, urllib.request

REF = os.environ.get('SUPABASE_PROJECT', 'wtrelwtztkddfktrfdpb')


def q(sql):
    token = os.environ.get('SUPABASE_ACCESS_TOKEN')
    if not token:
        sys.exit('Falta SUPABASE_ACCESS_TOKEN en el entorno.')
    req = urllib.request.Request(
        f'https://api.supabase.com/v1/projects/{REF}/database/query',
        data=json.dumps({'query': sql}).encode('utf-8'),
        headers={'Authorization': 'Bearer ' + token,
                 'Content-Type': 'application/json'},
        method='POST')
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(f'HTTP {e.code}: {e.read().decode("utf-8", "replace")[:1200]}')


def cargar():
    principios = q("""select id, principio_activo, sinonimos, grupo_clasificacion, grupo_fuente
                       from public.vetdosis_farmacologico_principios order by principio_activo""")
    pautas = q("""select * from public.vetdosis_farmacologico_pautas order by id""")
    return principios, pautas


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--asset', help='ruta del JSON a escribir')
    args = ap.parse_args()

    principios, pautas = cargar()
    calculables = sum(1 for p in pautas if p['dosis_min'] and p['base_calculo'])

    doc = {'schema_version': 1,
           'principios': len(principios),
           'pautas': len(pautas),
           'pautas_calculables': calculables,
           'farmacos': principios,
           'dosis': pautas}
    crudo = json.dumps(doc, ensure_ascii=False, sort_keys=True, separators=(',', ':'))
    version = 'v1-' + hashlib.sha256(crudo.encode('utf-8')).hexdigest()[:12]

    q(f"""update public.vetdosis_farmacologico_version
             set version = '{version}', principios = {len(principios)},
                 pautas = {len(pautas)}, calculables = {calculables},
                 actualizado_en = now()
           where id = 1""")

    if args.asset:
        with open(args.asset, 'w', encoding='utf-8') as f:
            json.dump(doc, f, ensure_ascii=False, indent=1)
        print(f'asset: {args.asset} ({os.path.getsize(args.asset)/1024:.0f} KB)')
    print(f'version: {version} · principios {len(principios)} · pautas {len(pautas)} · calculables {calculables}')


if __name__ == '__main__':
    main()
