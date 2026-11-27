#!/usr/bin/env python3
"""Grupo de clasificación (I/II/III) de cada principio activo.

Fuente: Acuerdo publicado en el DOF el 05/03/2012. El PDF trae tres columnas y
el texto plano las desalinea, así que la asignación se hace por la coordenada x
de arranque de cada línea, con anclas globales y unión de nombres partidos.

Solo se acepta nombre idéntico, variante ortográfica de una lista cerrada, forma
de sal o variación de la vocal final. Nada de coincidencia difusa: emparejaba
Fenobarbital con Pentobarbital y Metadona con Metadiona.

Uso:
  python3 grupo_clasificacion.py --pdf ACUERDO....pdf            (solo informe)
  python3 grupo_clasificacion.py --pdf ... --aplicar             (escribe en la base)
"""
import argparse, json, os, re, sys, unicodedata, urllib.error, urllib.request
from collections import Counter

import pypdf

TOL, UNION, DRIFT = 6.0, 12.0, 12.0
RUIDO = re.compile(r'^(\d+/22$|http|DOF|4/4/2017|\(Se |CLASE$|SUBCLASE$|CLASIFICACI)', re.I)
FRASE = re.compile(r'^(Grupo\s+I{1,3}$)')

VARIANTES = {
    'metoclorpramida': 'metoclopramida', 'midazolan': 'midazolam', 'diacepan': 'diazepam',
    'loracepan': 'lorazepam', 'isofluorano': 'isoflurano', 'betametazona': 'betametasona',
    'hidroclortiazida': 'hidroclorotiazida', 'flucloxicilina': 'flucloxacilina',
    'esprinomectina': 'eprinomectina', 'doxopram': 'doxapram',
    'espirolactona': 'espironolactona', 'clorfeniramina': 'clorfenamina',
    'deslorelin': 'deslorelina', 'n acetilcisteina': 'acetilcisteina',
    'acido acetil salicilico': 'acido acetilsalicilico',
}
SALES = re.compile(r'^(clorhidrato|hidrocloruro|sulfato|bromuro|fosfato|acetato|citrato|'
                   r'maleato|fumarato|tartrato|nitrato|oxalato) (de |del )?')


def base(s):
    s = s.replace('\xa0', ' ')
    s = ''.join(c for c in unicodedata.normalize('NFD', s) if not unicodedata.combining(c))
    s = s.lower()
    s = re.sub(r'\ba cido\b', 'acido', s)
    s = re.sub(r'\bac\b', 'acido', s)
    s = re.sub(r'^cido ', 'acido ', s)
    s = re.sub(r'\(\s*via\s*\)', ' ', s)
    s = re.sub(r'\(.*?\)', ' ', s)
    s = re.sub(r'[^a-z0-9]+', ' ', s)
    return ' '.join(s.split())


def claves(s):
    """Formas equivalentes de un nombre: exacta, sin sal, con c por z y sin vocal final."""
    k = base(s)
    k = VARIANTES.get(k, k)
    out = {'exacto': k}
    sin_sal = SALES.sub('', k)
    if sin_sal != k and len(sin_sal) >= 5:
        out['sal'] = sin_sal
    kc = k.replace('z', 'c')
    out['ceceo'] = kc
    partes = kc.split()
    if partes and partes[-1][-1] in 'ao':
        out['vocal'] = ' '.join(partes[:-1] + [partes[-1][:-1]])
    return out


def fragmentos(pagina):
    out = []

    def visitor(text, cm, tm, font, size):
        t = re.sub(r'\s+', ' ', text.replace('\xa0', ' ')).strip()
        if t and not RUIDO.match(t):
            out.append((round(tm[4], 1), round(tm[5], 1), t))

    pagina.extract_text(visitor_text=visitor)
    return out


def agrupar(xs):
    g = []
    for x in sorted(set(xs)):
        if g and x - g[-1][-1] <= TOL:
            g[-1].append(x)
        else:
            g.append([x])
    return [sum(c) / len(c) for c in g]


def leer_pdf(ruta):
    paginas = [fragmentos(p) for p in pypdf.PdfReader(ruta).pages]
    todas = [x for fs in paginas for x, _, _ in fs if x > 280]
    grandes = sorted(c for c in agrupar(todas)
                     if sum(1 for x in todas if abs(x - c) <= TOL) >= 20)
    if len(grandes) < 3:
        sys.exit(f'No se distinguen las tres columnas: {grandes}')
    anclas = dict(zip(('I', 'II', 'III'), grandes[-3:]))

    filas = []
    for n, fs in enumerate(paginas, start=1):
        por_col = {}
        for x, y, t in fs:
            g = next((g for g, a in anclas.items() if abs(x - a) <= UNION), None)
            if g:
                por_col.setdefault(g, []).append((y, t))
        for g, items in por_col.items():
            items.sort(key=lambda a: -a[0])
            buf = []
            for y, t in items:
                if buf and abs(buf[-1][0] - y) <= 12:
                    buf[-1] = (y, buf[-1][1] + ' ' + t)
                else:
                    buf.append((y, t))
            for y, t in buf:
                if t.startswith('(') or not 3 <= len(t) <= 40:
                    continue
                if n == 1 and y > 530:          # cuerpo del considerando, no tabla
                    continue
                if FRASE.match(t) or t.endswith((',', ' y')) or ' y su ' in t:
                    continue
                if re.search(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]', t):
                    filas.append({'grupo': g, 'texto': re.sub(r'\s+', ' ', t).strip()})
    return filas


def indice(filas):
    gn = {}
    for f in filas:
        if len(base(f['texto'])) < 4:
            continue
        for tipo, c in claves(f['texto']).items():
            gn.setdefault((tipo, c), set()).add(f['grupo'])
    return gn


def cruzar(gn, principios):
    salida = []
    for p in principios:
        grupos, tipos = set(), set()
        for tipo, c in claves(p['principio_activo']).items():
            g = gn.get((tipo, c), set())
            if len(g) == 1 or (len(g) > 1 and not grupos):
                grupos |= g
                tipos.add(tipo)
        if len(grupos) == 1:
            salida.append({'id': p['id'], 'bloque': p['bloque_origen'],
                           'grupo': list(grupos)[0],
                           'metodo': 'exacto' if 'exacto' in tipos else 'variante'})
    return salida


def sql(v):
    token = os.environ.get('SUPABASE_ACCESS_TOKEN')
    if not token:
        sys.exit('Falta SUPABASE_ACCESS_TOKEN en el entorno.')
    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{os.environ.get('SUPABASE_PROJECT', 'wtrelwtztkddfktrfdpb')}/database/query",
        data=json.dumps({'query': v}).encode('utf-8'),
        headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'},
        method='POST')
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(f'HTTP {e.code}: {e.read().decode("utf-8", "replace")[:1200]}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--pdf', required=True)
    ap.add_argument('--aplicar', action='store_true')
    args = ap.parse_args()

    filas = leer_pdf(args.pdf)
    print('ingredientes extraídos:', len(filas), Counter(f['grupo'] for f in filas))

    principios = sql("select id_farmaco_original id, principio_activo, bloque_origen "
                     "from private.vetdosis_qwen_farmacos_revision")
    datos = cruzar(indice(filas), principios)
    print('con grupo:', len(datos), 'de', len(principios),
          Counter(d['grupo'] for d in datos))

    if not args.aplicar:
        return
    valores = ',\n'.join(f"('{d['bloque']}','{d['id']}','{d['grupo']}','{d['metodo']}')" for d in datos)
    sql("update private.vetdosis_qwen_farmacos_revision "
        "set grupo_clasificacion=null, grupo_metodo=null where grupo_fuente like 'ACUERDO%'")
    sql("update private.vetdosis_qwen_dosis_revision set grupo_clasificacion=null")
    sql(f"""update private.vetdosis_qwen_farmacos_revision f
               set grupo_clasificacion=v.g, grupo_metodo=v.m,
                   grupo_fuente='ACUERDO DOF 05/03/2012 (clasificación por nivel de riesgo)',
                   grupo_actualizado_en=date '2026-11-26'
              from (values {valores}) as v(b,id,g,m)
             where f.bloque_origen=v.b and f.id_farmaco_original=v.id""")
    sql("""update private.vetdosis_qwen_dosis_revision d
              set grupo_clasificacion=f.grupo_clasificacion
             from private.vetdosis_qwen_farmacos_revision f
            where f.bloque_origen=d.bloque_origen
              and f.id_farmaco_original=d.id_farmaco_original
              and f.grupo_clasificacion is not null""")
    print('aplicado')


if __name__ == '__main__':
    main()
