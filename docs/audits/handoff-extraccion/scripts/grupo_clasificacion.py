#!/usr/bin/env python3
# Extrae el grupo (I/II/III) de cada ingrediente activo del Acuerdo DOF 05/03/2012
# y lo cruza con los principios activos de la base. Requiere pypdf.

#!/usr/bin/env python3
"""Ingredientes del Acuerdo por grupo, con anclas globales.

Las tres columnas caen siempre en ~299/435/554 (con deriva de hasta 5 pt), así
que se agrupan todas las x de contenido, se descartan pie con cabecera, y se
asignan por orden: izquierda=I, centro=II, derecha=III.
"""
import glob, json, re
from collections import Counter
import pypdf

RUIDO = re.compile(r'^(\d+/22$|http|DOF|4/4/2017|\(Se |CLASE$|SUBCLASE$|CLASIFICACI)', re.I)
TOL, UNION = 6.0, 12.0


def frags(pagina):
    out = []

    def v(text, cm, tm, font, size):
        t = re.sub(r'\s+', ' ', text.replace('\xa0', ' ')).strip()
        if t and not RUIDO.match(t):
            out.append((round(tm[4], 1), round(tm[5], 1), t))

    pagina.extract_text(visitor_text=v)
    return out


def cluster(xs):
    g = []
    for x in sorted(set(xs)):
        if g and x - g[-1][-1] <= TOL:
            g[-1].append(x)
        else:
            g.append([x])
    return [sum(c) / len(c) for c in g]


def extraer(ruta):
    paginas = [frags(p) for p in pypdf.PdfReader(ruta).pages]
    todas = [x for fs in paginas for x, _, _ in fs if x > 280]
    cols = cluster(todas)
    grandes = [c for c in cols if sum(1 for x in todas if abs(x - c) <= TOL) >= 20]
    grandes.sort()
    if len(grandes) < 3:
        raise SystemExit(f'columnas insuficientes: {grandes}')
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
                if t.startswith('(') or len(t) < 3 or len(t) > 40:
                    continue
                if n == 1 and y > 530:
                    continue
                if re.match(r'^Grupo\s+I{1,3}$', t):
                    continue
                if t.endswith((',', ' y')) or ' y su ' in t:
                    continue
                if re.search(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]', t):
                    filas.append({'grupo': g, 'texto': re.sub(r'\s+', ' ', t).strip(), 'pagina': n})
    return filas, anclas


if __name__ == '__main__':
    ruta = [x for x in glob.glob('/workspace/project/*.pdf') if 'ACUERDO' in x][0]
    filas, anclas = extraer(ruta)
    print('anclas:', anclas)
    print('filas:', len(filas), Counter(f['grupo'] for f in filas))
    json.dump(filas, open('/tmp/acuerdo_filas2.json', 'w'), ensure_ascii=False, indent=0)
    for g in ('I', 'II', 'III'):
        ej = [f['texto'] for f in filas if f['grupo'] == g]
        print(f'\nGrupo {g} ({len(ej)}):', ' · '.join(ej[:12]))
