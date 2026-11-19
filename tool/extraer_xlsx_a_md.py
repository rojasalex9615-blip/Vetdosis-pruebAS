"""Vuelca hojas de .xlsx a Markdown para poder leerlas y revisarlas en git.

Uso:
    python3 tool/extraer_xlsx_a_md.py docs/product/fuentes/*.xlsx

Escribe un .md junto a cada .xlsx, con una seccion por hoja y los valores tal
como estan en el libro. Las formulas se emiten como formula y, cuando el libro
guarda el resultado calculado, tambien como valor.
"""

from __future__ import annotations

import sys
from pathlib import Path

import openpyxl


def _cell(value: object) -> str:
    if value is None:
        return ""
    return str(value).replace("|", "\\|").replace("\n", " ").strip()


def sheet_to_markdown(ws: openpyxl.worksheet.worksheet.Worksheet) -> list[str]:
    rows = [
        [_cell(c.value) for c in row]
        for row in ws.iter_rows(max_row=ws.max_row, max_col=ws.max_column)
    ]
    rows = [r for r in rows if any(cell for cell in r)]
    if not rows:
        return ["_(hoja vacia)_", ""]

    width = max(len(r) for r in rows)
    rows = [r + [""] * (width - len(r)) for r in rows]

    out = ["| " + " | ".join(rows[0]) + " |"]
    out.append("|" + "|".join([" --- "] * width) + "|")
    for r in rows[1:]:
        out.append("| " + " | ".join(r) + " |")
    out.append("")
    return out


def convert(path: Path) -> Path:
    wb = openpyxl.load_workbook(path, data_only=False)
    cached = openpyxl.load_workbook(path, data_only=True)

    lines = [
        f"# {path.name}",
        "",
        f"Extraido de `{path.name}` para poder leerlo sin herramienta de hoja de calculo.",
        "Las celdas muestran la formula cuando la hay; el valor calculado solo",
        "aparece si el libro lo guardo en el ultimo guardado.",
        "",
    ]

    for ws in wb.worksheets:
        lines.append(f"## Hoja `{ws.title}`")
        lines.append("")
        lines.append(f"Rango con datos: {ws.max_row} filas x {ws.max_column} columnas.")
        lines.append("")
        lines.extend(sheet_to_markdown(ws))

        ws_cached = cached[ws.title]
        formulas = [
            (c.coordinate, c.value, ws_cached[c.coordinate].value)
            for row in ws.iter_rows()
            for c in row
            if isinstance(c.value, str) and c.value.startswith("=")
        ]
        if formulas:
            lines.append(f"### Formulas de `{ws.title}` ({len(formulas)})")
            lines.append("")
            lines.append("| Celda | Formula | Valor guardado |")
            lines.append("| --- | --- | --- |")
            for coord, formula, value in formulas:
                lines.append(f"| {coord} | `{_cell(formula)}` | {_cell(value)} |")
            lines.append("")

    target = path.with_suffix(".md")
    target.write_text("\n".join(lines), encoding="utf-8")
    return target


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__, file=sys.stderr)
        return 2
    for name in argv:
        path = Path(name)
        if not path.exists():
            print(f"no existe: {path}", file=sys.stderr)
            return 1
        target = convert(path)
        print(f"{path} -> {target} ({target.stat().st_size} B)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
