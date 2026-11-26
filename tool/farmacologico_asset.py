#!/usr/bin/env python3
"""Genera assets/clinical/farmacologico.v1.json desde las vistas públicas.

Las vistas son de solo lectura y las puede leer la clave publicable, que es la
misma que usa la app. Así el asset se construye por el mismo camino por el que
la app se actualizará después.

PostgREST corta en 1.000 filas por respuesta y hay más de mil pautas: se pagina
siempre, o se pierden filas sin avisar.

Variables de entorno:
  SUPABASE_URL               por defecto https://wtrelwtztkddfktrfdpb.supabase.co
  SUPABASE_PUBLISHABLE_KEY   clave publicable del proyecto

Uso: python3 tool/farmacologico_asset.py [--salida assets/clinical/farmacologico.v1.json]
"""
import argparse, json, os, sys, urllib.error, urllib.request

BASE = os.environ.get('SUPABASE_URL', 'https://wtrelwtztkddfktrfdpb.supabase.co').rstrip('/')
CLAVE = os.environ.get('SUPABASE_PUBLISHABLE_KEY')
PAGINA = 1000


def pedir(ruta):
    if not CLAVE:
        sys.exit('Falta SUPABASE_PUBLISHABLE_KEY en el entorno.')
    req = urllib.request.Request(
        f'{BASE}/rest/v1/{ruta}',
        headers={'apikey': CLAVE, 'Authorization': f'Bearer {CLAVE}'})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(f'HTTP {e.code}: {e.read().decode("utf-8", "replace")[:800]}')


def todas(tabla, orden):
    filas, desde = [], 0
    while True:
        trozo = pedir(f'{tabla}?select=*&order={orden}&limit={PAGINA}&offset={desde}')
        filas.extend(trozo)
        if len(trozo) < PAGINA:
            return filas
        desde += PAGINA


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--salida', default='assets/clinical/farmacologico.v1.json')
    args = ap.parse_args()

    version = pedir('vetdosis_farmacologico_version?select=*')
    if not version:
        sys.exit('La tabla de versión está vacía.')
    meta = version[0]

    farmacos = todas('vetdosis_farmacologico_principios', 'id')
    dosis = todas('vetdosis_farmacologico_pautas', 'id')

    if len(farmacos) != meta['principios'] or len(dosis) != meta['pautas']:
        sys.exit(f'Descuadre: {len(farmacos)}/{meta["principios"]} principios, '
                 f'{len(dosis)}/{meta["pautas"]} pautas. ¿Falta paginación?')

    doc = {
        'schema_version': 1,
        'version': meta['version'],
        'generado_en': meta['actualizado_en'],
        'principios': len(farmacos),
        'pautas': len(dosis),
        'pautas_calculables': meta['calculables'],
        'farmacos': farmacos,
        'dosis': dosis,
    }
    with open(args.salida, 'w', encoding='utf-8') as f:
        json.dump(doc, f, ensure_ascii=False, separators=(',', ':'))
    kb = os.path.getsize(args.salida) / 1024
    print(f'{args.salida}: {len(farmacos)} principios, {len(dosis)} pautas, '
          f'{meta["calculables"]} calculables, {kb:.0f} KB, versión {meta["version"]}')


if __name__ == '__main__':
    main()
