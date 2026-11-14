#!/usr/bin/env python3
"""Calca los iconos de VetDosis a SVG de un solo trazo.

Dos origenes, un mismo calco (potrace), para que todos compartan estilo:

  sheets/*.png      Las laminas que entrego Ale. Se recorta cada icono por su
                    hueco en la cuadricula y se nombra con sheets/names.json.
  authored/*.svg    Los que faltaban, dibujados a mano con trazos gruesos y
                    puntas redondas. Se rasterizan con render_authored.js.

Salida: svg/<nombre>.svg en lienzo 24x24. Los de las laminas se ajustan a 20
de lado mayor y se centran (2 de margen, como los iconos de Material); los de
authored/ conservan el tamano con que se dibujaron.

Requiere: pillow, numpy, potracer; y node + playwright para authored/.
Uso: python3 tools/icons/trace.py
"""
import json
import os
import subprocess
import sys
import tempfile

import numpy as np
import potrace
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'svg')
SIDE = 900  # lado en pixeles al que se calca cada icono


def runs(mask, min_gap):
    """Tramos con tinta separados por al menos min_gap pixeles en blanco."""
    idx = np.where(mask)[0]
    if len(idx) == 0:
        return []
    out, start, prev = [], idx[0], idx[0]
    for i in idx[1:]:
        if i - prev > min_gap:
            out.append((start, prev + 1))
            start = i
        prev = i
    out.append((start, prev + 1))
    return out


def boxes(gray, col_gap):
    """Caja de cada icono de una lamina, en orden de lectura."""
    ink = np.array(gray) < 128
    found = []
    for y0, y1 in runs(ink.sum(1) > 0, 18):
        if y1 - y0 < 25:
            continue
        for x0, x1 in runs(ink[y0:y1].sum(0) > 0, col_gap):
            ys = np.where(ink[y0:y1, x0:x1].sum(1) > 0)[0]
            found.append((x0, y0 + ys[0], x1, y0 + ys[-1] + 1))
    return found


def fmt(v):
    return f'{v:.2f}'.rstrip('0').rstrip('.')


def trace(gray, blur, fit=True):
    """Imagen en grises (tinta oscura) -> atributo d de un path en 24x24.

    Con fit se ajusta el dibujo a 20 de lado mayor y se centra; sin fit se
    respeta la posicion y el tamano con que se dibujo (un chevron o un punto
    no deben crecer hasta llenar el lienzo).
    """
    w, h = gray.size
    s = SIDE / max(w, h)
    big = gray.resize((round(w * s), round(h * s)), Image.BICUBIC)
    if blur:
        big = big.filter(ImageFilter.GaussianBlur(s * blur))
    ink = np.array(big) < 128
    ys, xs = np.where(ink)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    if fit:
        k = 20 / max(x1 - x0, y1 - y0)
        ox, oy = 12 - (x0 + x1) / 2 * k, 12 - (y0 + y1) / 2 * k
    else:
        k, ox, oy = 24 / max(big.size), 0, 0
    p = lambda pt: f'{fmt(pt.x * k + ox)} {fmt(pt.y * k + oy)}'
    # potracer calca lo que es False: se le pasa el fondo.
    curves = potrace.Bitmap(~ink).trace(
        turdsize=60, alphamax=1.15, opticurve=True, opttolerance=0.6)
    d = []
    for curve in curves:
        d.append('M' + p(curve.start_point))
        for seg in curve.segments:
            if seg.is_corner:
                d.append(f'L{p(seg.c)}L{p(seg.end_point)}')
            else:
                d.append(f'C{p(seg.c1)} {p(seg.c2)} {p(seg.end_point)}')
        d.append('Z')
    return ''.join(d)


def write(name, d):
    with open(os.path.join(OUT, name + '.svg'), 'w') as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
                f'<path fill="currentColor" fill-rule="evenodd" d="{d}"/>'
                '</svg>\n')


def main():
    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):
        os.remove(os.path.join(OUT, old))
    names = json.load(open(os.path.join(HERE, 'sheets', 'names.json')))
    done = {}
    for key in names['prioridad']:
        gray = Image.open(os.path.join(HERE, 'sheets', key + '.png')).convert('L')
        found = boxes(gray, 22 if key == 'a' else 24)
        wanted = names[key].split()
        if len(found) != len(wanted):
            sys.exit(f'lamina {key}: {len(found)} iconos, {len(wanted)} nombres')
        for (x0, y0, x1, y1), name in zip(found, wanted):
            if name.startswith('-') or name in done:
                continue
            crop = gray.crop((x0 - 6, y0 - 6, x1 + 6, y1 + 6))
            write(name, trace(crop, 0.55))
            done[name] = key
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(
            ['node', os.path.join(HERE, 'render_authored.js'), tmp, str(SIDE)],
            check=True)
        for png in sorted(os.listdir(tmp)):
            name = png[:-4]
            if name in done:
                sys.exit(f'authored/{name}.svg repite un icono de las laminas')
            gray = Image.open(os.path.join(tmp, png)).convert('L')
            write(name, trace(gray, 0, fit=False))
            done[name] = 'authored'
    json.dump(dict(sorted(done.items())),
              open(os.path.join(HERE, 'sources.json'), 'w'), indent=1)
    print(f'{len(done)} iconos en {OUT}')


if __name__ == '__main__':
    main()
