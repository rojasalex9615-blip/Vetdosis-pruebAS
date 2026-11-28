#!/usr/bin/env python3
"""Audita riesgos de desbordamiento (RenderFlex overflow) y texto cortado.

Analiza los archivos Dart de `lib/` sin necesidad del SDK de Flutter: enmascara
cadenas y comentarios, localiza las llamadas a widgets, extrae la lista real de
`children` de cada `Row`/`Column` y marca los hijos que pueden desbordar en
anchos de telefono.

Uso:
    python3 scripts/validation/audit_overflow.py            # resumen
    python3 scripts/validation/audit_overflow.py --json out.json
    python3 scripts/validation/audit_overflow.py --rule row_text
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
LIB = ROOT / "lib"

# Widgets que ceden espacio a un hijo flexible.
FLEX_WRAPPERS = {"Expanded", "Flexible", "Spacer"}
# Widgets que no imponen el ancho del padre y por tanto siguen en riesgo.
RISKY_LEAF = {"Text", "SelectableText", "RichText"}
RISKY_BOX = {"Column", "Row", "Wrap", "Container", "DecoratedBox", "Card"}


def mask_strings_and_comments(src: str) -> str:
    """Devuelve el codigo con cadenas y comentarios sustituidos por espacios.

    Conserva longitud y saltos de linea para que los offsets sigan siendo
    validos contra el texto original.
    """
    out = list(src)
    i = 0
    n = len(src)
    while i < n:
        ch = src[i]
        # Comentario de linea
        if ch == "/" and i + 1 < n and src[i + 1] == "/":
            j = src.find("\n", i)
            j = n if j == -1 else j
            for k in range(i, j):
                out[k] = " "
            i = j
            continue
        # Comentario de bloque
        if ch == "/" and i + 1 < n and src[i + 1] == "*":
            j = src.find("*/", i + 2)
            j = n if j == -1 else j + 2
            for k in range(i, j):
                if src[k] != "\n":
                    out[k] = " "
            i = j
            continue
        if ch in "'\"":
            raw = i > 0 and src[i - 1] == "r"
            triple = src.startswith(ch * 3, i)
            quote = ch * 3 if triple else ch
            j = i + len(quote)
            while j < n:
                if not raw and src[j] == "\\":
                    j += 2
                    continue
                if src.startswith(quote, j):
                    j += len(quote)
                    break
                j += 1
            else:
                j = n
            for k in range(i, min(j, n)):
                if src[k] != "\n":
                    out[k] = " "
            i = j
            continue
        i += 1
    return "".join(out)


def match_close(masked: str, open_idx: int) -> int:
    """Indice del cierre que corresponde al parentesis/corchete en open_idx."""
    pairs = {"(": ")", "[": "]", "{": "}"}
    opener = masked[open_idx]
    closer = pairs[opener]
    depth = 0
    for i in range(open_idx, len(masked)):
        c = masked[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                return i if c == closer else -1
    return -1


def split_top_level(masked: str, start: int, end: int) -> list[tuple[int, int]]:
    """Rangos de los elementos separados por comas de primer nivel en [start, end)."""
    parts = []
    depth = 0
    cur = start
    for i in range(start, end):
        c = masked[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "," and depth == 0:
            parts.append((cur, i))
            cur = i + 1
    if masked[cur:end].strip():
        parts.append((cur, end))
    return [(a, b) for a, b in parts if masked[a:b].strip()]


ARG_NAME = re.compile(r"^\s*([a-zA-Z_][A-Za-z0-9_]*)\s*:")


def named_args(masked: str, open_paren: int, close_paren: int) -> dict[str, tuple[int, int]]:
    """Mapa nombre -> rango del valor, para los argumentos con nombre."""
    args: dict[str, tuple[int, int]] = {}
    for a, b in split_top_level(masked, open_paren + 1, close_paren):
        m = ARG_NAME.match(masked[a:b])
        if m:
            args[m.group(1)] = (a + m.end(), b)
    return args


# Prefijos que no son el widget real del elemento de una lista `children`.
LEADING_NOISE = re.compile(
    r"^\s*(?:const\s+|new\s+|\.\.\.\??\s*|if\s*\([^)]*\)\s*|else\s+|for\s*\([^)]*\)\s*)*"
)
IDENT = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)")


def element_widget(masked: str, a: int, b: int) -> tuple[str | None, int]:
    """Nombre del widget de un elemento de `children` y el offset donde empieza."""
    text = masked[a:b]
    pos = LEADING_NOISE.match(text).end()
    m = IDENT.search(text, pos)
    if not m:
        return None, a
    return m.group(1), a + m.start()


def line_of(src: str, idx: int) -> int:
    return src.count("\n", 0, idx) + 1


def snippet(src: str, idx: int, width: int = 110) -> str:
    start = src.rfind("\n", 0, idx) + 1
    end = src.find("\n", idx)
    end = len(src) if end == -1 else end
    return src[start:end].strip()[:width]


def text_is_dynamic(src: str, a: int, b: int) -> bool:
    """True si el Text no es una cadena literal corta y fija."""
    body = src[a:b]
    m = re.search(r"\bText\s*\(", body)
    if not m:
        return True
    inner = body[m.end():]
    # Primer argumento posicional hasta la coma de primer nivel.
    depth = 0
    first = inner
    for i, c in enumerate(inner):
        if c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                first = inner[:i]
                break
            depth -= 1
        elif c == "," and depth == 0:
            first = inner[:i]
            break
    first = first.strip()
    if "$" in first or "." in first or "(" in first:
        return True
    lit = re.fullmatch(r"'([^']*)'|\"([^\"]*)\"", first)
    if lit:
        value = lit.group(1) if lit.group(1) is not None else lit.group(2)
        return len(value) > 18
    return True


def has_clamp(src: str, a: int, b: int) -> bool:
    body = src[a:b]
    return "overflow:" in body or "maxLines:" in body or "softWrap:" in body


# Tamanos por defecto del TextTheme de Material 3.
TEXT_STYLE_SIZES = {
    "displayLarge": 57, "displayMedium": 45, "displaySmall": 36,
    "headlineLarge": 32, "headlineMedium": 28, "headlineSmall": 24,
    "titleLarge": 22, "titleMedium": 16, "titleSmall": 14,
    "bodyLarge": 16, "bodyMedium": 14, "bodySmall": 12,
    "labelLarge": 14, "labelMedium": 12, "labelSmall": 11,
}

# Ancho de contenido util dentro de una VetCard en un telefono de 360 dp:
# 360 - 16*2 (padding de pantalla) - 17*2 (padding de VetCard con su borde).
PHONE_CARD_WIDTH = 294.0


# Valor estimado para lo que ocupa una interpolacion al pintarse.
INTERPOLATION_CHARS = 6


def _rendered_length(literal: str) -> int:
    """Caracteres que se pintan: las interpolaciones cuentan como un valor corto."""
    shown = re.sub(r"\$\{[^{}]*\}", "X" * INTERPOLATION_CHARS, literal)
    shown = re.sub(r"\$[A-Za-z_][A-Za-z0-9_]*", "X" * INTERPOLATION_CHARS, shown)
    return len(shown)


def first_positional_arg(body: str, call_end: int) -> str:
    """Primer argumento posicional de la llamada que empieza en call_end."""
    depth = 0
    for i in range(call_end, len(body)):
        c = body[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                return body[call_end:i]
            depth -= 1
        elif c == "," and depth == 0:
            return body[call_end:i]
    return body[call_end:]


def estimate_text_width(src: str, a: int, b: int) -> tuple[float, str]:
    """Ancho aproximado en dp del Text del rango, y la cadena medida."""
    body = src[a:b]
    m = re.search(r"\bText\s*\(", body)
    if not m:
        return 0.0, ""
    size = 14.0
    sm = re.search(r"fontSize\s*:\s*([0-9.]+)", body)
    if sm:
        size = float(sm.group(1))
    else:
        for name, value in TEXT_STYLE_SIZES.items():
            if f".{name}" in body:
                size = float(value)
                break
    bold = bool(re.search(r"FontWeight\.(w[6-9]00|bold)", body))

    arg = first_positional_arg(body, m.end())
    literals = [x or y for x, y in re.findall(r"'([^'\n]*)'|\"([^\"\n]*)\"", arg)]
    if not literals:
        # Variable o llamada: no se puede medir, se asume un valor corto.
        chars = 12
        text = "<dinamico>"
    else:
        # En un ternario solo se pinta una rama, asi que se toma la mas larga;
        # si no lo hay, las cadenas van concatenadas y se suman.
        ternary = re.search(r"(?<![?.])\?(?![.?])", arg) is not None
        lengths = [_rendered_length(s) for s in literals]
        chars = max(lengths) if ternary else sum(lengths)
        text = max(literals, key=len) if ternary else "".join(literals)
    factor = 0.53 if bold else 0.50
    return chars * size * factor, text


def estimate_row_width(src: str, masked: str, elements: list[tuple[int, int]]) -> float:
    """Ancho minimo aproximado de una Row sumando el de sus hijos conocidos."""
    total = 0.0
    for a, b in elements:
        body = src[a:b]
        kind, _ = element_widget(masked, a, b)
        if kind in ("Icon", "ImageIcon"):
            sm = re.search(r"size\s*:\s*([0-9.]+)", body)
            total += float(sm.group(1)) if sm else 24.0
        elif kind == "SizedBox":
            sm = re.search(r"width\s*:\s*([0-9.]+)", body)
            total += float(sm.group(1)) if sm else 0.0
        elif kind in RISKY_LEAF:
            total += estimate_text_width(src, a, b)[0]
        elif kind in ("IconButton",):
            total += 48.0
        elif kind == "Container":
            sm = re.search(r"width\s*:\s*([0-9.]+)", body)
            total += float(sm.group(1)) if sm else 0.0
    return total


def analyze_file(path: pathlib.Path) -> list[dict]:
    src = path.read_text(encoding="utf-8")
    masked = mask_strings_and_comments(src)
    findings: list[dict] = []
    rel = str(path.relative_to(ROOT))

    for m in re.finditer(
        r"\b(Row|Column|GridView|SizedBox|Container)(?:\.[A-Za-z_][A-Za-z0-9_]*)?\s*\(", masked
    ):
        widget = m.group(1)
        open_paren = m.end() - 1
        close_paren = match_close(masked, open_paren)
        if close_paren == -1:
            continue
        args = named_args(masked, open_paren, close_paren)

        if widget in ("Row", "Column"):
            if "children" not in args:
                continue
            ca, cb = args["children"]
            lb = masked.find("[", ca, cb)
            if lb == -1:
                continue
            rb = match_close(masked, lb)
            if rb == -1 or rb > cb:
                continue
            elements = split_top_level(masked, lb + 1, rb)
            kinds = [element_widget(masked, a, b) for a, b in elements]
            flexible = sum(1 for k, _ in kinds if k in FLEX_WRAPPERS)
            row_width = estimate_row_width(src, masked, elements) if widget == "Row" else 0.0

            for (a, b), (kind, kpos) in zip(elements, kinds):
                if kind in FLEX_WRAPPERS or kind is None:
                    continue
                if widget == "Row" and kind in RISKY_LEAF:
                    dynamic = text_is_dynamic(src, a, b)
                    if dynamic:
                        findings.append(
                            {
                                "rule": "row_text",
                                "severity": "alta" if flexible == 0 else "media",
                                "file": rel,
                                "line": line_of(src, kpos),
                                "detail": (
                                    "Text de ancho libre dentro de Row sin Expanded/Flexible"
                                    + ("" if flexible else "; la Row no tiene ningun hijo flexible")
                                ),
                                "clamped": has_clamp(src, a, b),
                                "est_width": round(row_width, 1),
                                "budget": PHONE_CARD_WIDTH,
                                "overflows_360dp": row_width > PHONE_CARD_WIDTH,
                                "code": snippet(src, kpos),
                            }
                        )
                elif widget == "Row" and kind in ("Column", "Wrap"):
                    findings.append(
                        {
                            "rule": "row_column",
                            "severity": "alta" if flexible == 0 else "media",
                            "file": rel,
                            "line": line_of(src, kpos),
                            "detail": f"{kind} dentro de Row sin Expanded/Flexible",
                            "clamped": False,
                            "code": snippet(src, kpos),
                        }
                    )

        elif widget == "GridView":
            body = masked[open_paren:close_paren]
            am = re.search(r"childAspectRatio\s*:\s*([0-9.]+)", body)
            if not am:
                continue
            ratio = float(am.group(1))
            cm = re.search(r"crossAxisCount\s*:\s*([0-9]+)", body)
            columns = int(cm.group(1)) if cm else 0
            # Alto util de una celda en un telefono de 360 dp.
            cell_height = None
            if columns:
                sm = re.search(r"crossAxisSpacing\s*:\s*([0-9.]+)", body)
                spacing = float(sm.group(1)) if sm else 0.0
                cell_width = (360.0 - 32.0 - spacing * (columns - 1)) / columns
                cell_height = cell_width / ratio
            findings.append(
                {
                    "rule": "grid_aspect",
                    "severity": "alta" if cell_height and cell_height < 150 else "media",
                    "file": rel,
                    "line": line_of(src, m.start()),
                    "detail": (
                        f"GridView con childAspectRatio fijo ({ratio})"
                        + (
                            f"; en 360 dp la celda mide {cell_height:.0f} dp de alto y no crece"
                            " si el texto salta de linea"
                            if cell_height
                            else "; la celda no crece si el texto salta de linea"
                        )
                    ),
                    "clamped": False,
                    "cell_height": round(cell_height, 1) if cell_height else None,
                    "code": snippet(src, m.start()),
                }
            )

        else:  # SizedBox / Container con alto fijo y contenido de texto
            if "height" not in args or "child" not in args:
                continue
            ha, hb = args["height"]
            if not re.fullmatch(r"\s*[0-9.]+\s*", masked[ha:hb]):
                continue
            ca, cb = args["child"]
            child_src = src[ca:cb]
            if re.search(r"\b(Text|Column)\s*\(", child_src):
                findings.append(
                    {
                        "rule": "fixed_height_text",
                        "severity": "media",
                        "file": rel,
                        "line": line_of(src, m.start()),
                        "detail": f"{widget} de alto fijo ({masked[ha:hb].strip()}) con texto dentro",
                        "clamped": False,
                        "code": snippet(src, m.start()),
                    }
                )
    return findings


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", type=pathlib.Path)
    ap.add_argument("--rule")
    ap.add_argument("--severity")
    ap.add_argument("--file-filter")
    ap.add_argument("--limit", type=int, default=40)
    ap.add_argument(
        "--fail-on-overflow",
        action="store_true",
        help="Termina con error si alguna Row no cabe en un telefono de 360 dp.",
    )
    args = ap.parse_args()

    findings: list[dict] = []
    for path in sorted(LIB.rglob("*.dart")):
        findings.extend(analyze_file(path))

    if args.rule:
        findings = [f for f in findings if f["rule"] == args.rule]
    if args.severity:
        findings = [f for f in findings if f["severity"] == args.severity]
    if args.file_filter:
        findings = [f for f in findings if args.file_filter in f["file"]]

    by_rule: dict[str, int] = {}
    by_file: dict[str, int] = {}
    for f in findings:
        by_rule[f["rule"]] = by_rule.get(f["rule"], 0) + 1
        by_file[f["file"]] = by_file.get(f["file"], 0) + 1

    print(f"Total de hallazgos: {len(findings)}\n")
    print("Por regla:")
    for rule, count in sorted(by_rule.items(), key=lambda kv: -kv[1]):
        print(f"  {count:5d}  {rule}")
    print("\nArchivos con mas hallazgos:")
    for name, count in sorted(by_file.items(), key=lambda kv: -kv[1])[: args.limit]:
        print(f"  {count:5d}  {name}")

    if args.json:
        args.json.write_text(json.dumps(findings, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"\nDetalle en {args.json}")

    overflowing = [f for f in findings if f.get("overflows_360dp")]
    print(f"\nFilas que no caben en un telefono de 360 dp: {len(overflowing)}")
    for f in overflowing:
        print(f"  {f['est_width']:.0f} dp > {f['budget']:.0f} dp  {f['file']}:{f['line']}")
    if args.fail_on_overflow and overflowing:
        print(
            "\nCada una de estas filas se pinta cortada en un telefono estrecho.",
            "Se arregla envolviendo el texto en Expanded/Flexible o pasando la fila a Wrap.",
            sep="\n",
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
