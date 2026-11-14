#!/usr/bin/env python3
"""Arma la fuente de iconos de VetDosis a partir de svg/.

Genera:
  assets/fonts/VetIcons.ttf     un glifo por icono, en el area de uso privado
  lib/vet_ui/vet_icons.dart     una constante IconData por icono
  tools/icons/codepoints.json   nombre -> codigo, estable entre corridas

Un icono conserva su codigo aunque se agreguen otros: los nuevos toman el
siguiente libre. Asi un APK viejo y uno nuevo nunca difieren en que glifo
corresponde a un codigo ya publicado.

Requiere: fonttools. Uso: python3 tools/icons/build_font.py
"""
import json
import os
import re
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SVG = os.path.join(HERE, 'svg')
CODEPOINTS = os.path.join(HERE, 'codepoints.json')
FONT = os.path.join(ROOT, 'assets', 'fonts', 'VetIcons.ttf')
DART = os.path.join(ROOT, 'lib', 'vet_ui', 'vet_icons.dart')
EM = 1200          # 24 unidades de lienzo x 50
FIRST = 0xE900     # area de uso privado


def camel(name):
    head, *rest = name.split('_')
    return head + ''.join(p.capitalize() for p in rest)


def draw(d, pen):
    """Pasa al pen un path hecho solo de M, L, C y Z absolutos (los de trace.py)."""
    scale = EM / 24
    pt = lambda x, y: (float(x) * scale, EM - float(y) * scale)
    open_ = False
    for cmd, args in re.findall(r'([MLCZ])([^MLCZ]*)', d):
        n = re.findall(r'-?\d*\.?\d+', args)
        if cmd == 'M':
            if open_:
                pen.closePath()
            pen.moveTo(pt(n[0], n[1]))
            open_ = True
        elif cmd == 'L':
            pen.lineTo(pt(n[0], n[1]))
        elif cmd == 'C':
            pen.curveTo(pt(n[0], n[1]), pt(n[2], n[3]), pt(n[4], n[5]))
        elif cmd == 'Z' and open_:
            pen.closePath()
            open_ = False
    if open_:
        pen.closePath()


def main():
    names = sorted(f[:-4] for f in os.listdir(SVG) if f.endswith('.svg'))
    bad = [n for n in names if not re.fullmatch(r'[a-z][a-z0-9_]*', n)]
    if bad:
        sys.exit(f'nombres invalidos: {bad}')
    codes = json.load(open(CODEPOINTS)) if os.path.exists(CODEPOINTS) else {}
    gone = sorted(set(codes) - set(names))
    if gone:
        sys.exit(f'codepoints.json nombra iconos sin SVG: {gone}. '
                 'Quitar un icono publicado cambia la app: borralo a mano del '
                 'JSON si de verdad se retira.')
    nxt = max(codes.values(), default=FIRST - 1) + 1
    for name in names:
        if name not in codes:
            codes[name] = nxt
            nxt += 1

    glyphs = {'.notdef': TTGlyphPen(None).glyph()}
    for name in names:
        svg = open(os.path.join(SVG, name + '.svg')).read()
        d = re.search(r' d="([^"]+)"', svg).group(1)
        pen = TTGlyphPen(None)
        # reverse_direction: al voltear el eje Y se invierte el sentido de
        # cada contorno; se devuelve el exterior al sentido horario de TrueType.
        draw(d, Cu2QuPen(pen, max_err=0.6, reverse_direction=True))
        glyphs[name] = pen.glyph()

    order = ['.notdef'] + names
    fb = FontBuilder(EM, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap({codes[n]: n for n in names})
    fb.setupGlyf(glyphs)
    # El margen izquierdo declarado debe ser el xMin real del glifo. Con 0,
    # el motor de texto desplaza el dibujo hasta pegarlo al borde y todos los
    # iconos salen corridos unas 2 unidades de 24 hacia la izquierda.
    glyf = fb.font['glyf']
    fb.setupHorizontalMetrics({
        g: (EM, getattr(glyf[g], 'xMin', 0) if glyf[g].numberOfContours else 0)
        for g in order
    })
    fb.setupHorizontalHeader(ascent=EM, descent=0)
    fb.setupNameTable({'familyName': 'VetIcons', 'styleName': 'Regular'})
    fb.setupOS2(sTypoAscender=EM, sTypoDescender=0, sTypoLineGap=0,
                usWinAscent=EM, usWinDescent=0)
    fb.setupPost()
    # Sin fecha de corrida: la misma entrada debe dar el mismo archivo.
    fb.font['head'].created = fb.font['head'].modified = 0
    fb.save(FONT)

    json.dump(dict(sorted(codes.items(), key=lambda kv: kv[1])),
              open(CODEPOINTS, 'w'), indent=1)

    lines = [
        '// GENERADO por tools/icons/build_font.py. No editar a mano:',
        '// se agrega o cambia un icono en tools/icons/ y se vuelve a generar.',
        '',
        "import 'package:flutter/widgets.dart';",
        '',
        '/// Iconos propios de VetDosis: solidos, de esquinas redondas.',
        '///',
        '/// Se usan igual que los de Material: `Icon(VetIcons.paw)`. El catalogo',
        '/// con su dibujo esta en docs/design/iconos-vetdosis.md.',
        'abstract final class VetIcons {',
        "  static const _family = 'VetIcons';",
        '',
    ]
    for name in names:
        ident = camel(name)
        lines.append(f'  static const IconData {ident} = '
                     f'IconData(0x{codes[name]:04x}, fontFamily: _family);')
    lines += [
        '',
        '  /// Todos, por nombre de archivo; para el catalogo y las pruebas.',
        '  static const Map<String, IconData> all = {',
    ]
    lines += [f"    '{n}': {camel(n)}," for n in names]
    lines += ['  };', '}', '']
    open(DART, 'w').write('\n'.join(lines))
    print(f'{len(names)} iconos -> {os.path.relpath(FONT, ROOT)}, '
          f'{os.path.relpath(DART, ROOT)}')


if __name__ == '__main__':
    main()
