"""Vuelca fuentes de referencia a Markdown para poder leerlas y revisarlas en git.

Uso:
    python3 tool/extraer_fuentes_a_md.py docs/product/fuentes/*.xlsx
    python3 tool/extraer_fuentes_a_md.py docs/product/fuentes/*.csv

Escribe un .md junto a cada fuente:
- .xlsx: una seccion por hoja con los valores tal como estan en el libro. Las
  formulas se emiten como formula y, cuando el libro guarda el resultado
  calculado, tambien como valor.
- .csv: una tabla con todas las filas y columnas del archivo.
- .html: el texto visible del documento, sin etiquetas ni estilos.
- .json: el documento formateado, sin perder ninguna clave.
- .pdf: el texto de cada pagina. Si una pagina no trae texto (escaneada) se
  avisa en el volcado en vez de dejarla en blanco.
"""

from __future__ import annotations

import csv
import json
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

import openpyxl


def _cell(value: object) -> str:
    if value is None:
        return ""
    return str(value).replace("|", "\\|").replace("\n", " ").strip()


def _table(rows: list[list[str]]) -> list[str]:
    rows = [r for r in rows if any(cell for cell in r)]
    if not rows:
        return ["_(sin filas con datos)_", ""]
    width = max(len(r) for r in rows)
    rows = [r + [""] * (width - len(r)) for r in rows]
    out = ["| " + " | ".join(rows[0]) + " |"]
    out.append("|" + "|".join([" --- "] * width) + "|")
    for r in rows[1:]:
        out.append("| " + " | ".join(r) + " |")
    out.append("")
    return out


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


class _TextCollector(HTMLParser):
    """Recoge el texto visible conservando la estructura util: titulos,
    parrafos, listas y tablas (que se emiten como tablas Markdown)."""

    SKIP = {'script', 'style', 'head', 'title'}
    HEADINGS = {'h1', 'h2', 'h3', 'h4', 'h5', 'h6'}
    BLOCKS = {
        'p', 'div', 'section', 'article', 'header', 'footer', 'li',
        'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'br', 'dd', 'dt', 'label',
        'option', 'button', 'summary', 'figcaption',
    }

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.blocks: list[str] = []
        self._skip = 0
        self._buffer: list[str] = []
        self._in_table = 0
        self._rows: list[list[str]] = []
        self._row: list[str] = []
        self._cell: list[str] | None = None

    def _flush(self) -> None:
        text = re.sub(r'\s+', ' ', ''.join(self._buffer)).strip()
        if text:
            self.blocks.append(text)
        self._buffer = []

    def handle_starttag(self, tag, attrs):
        if tag in self.SKIP:
            self._skip += 1
            return
        if self._skip:
            return
        if tag == 'table':
            self._flush()
            self._in_table += 1
            self._rows = []
        elif tag == 'tr' and self._in_table:
            self._row = []
        elif tag in ('td', 'th') and self._in_table:
            self._cell = []
        elif tag in self.BLOCKS:
            self._flush()
            if tag in self.HEADINGS:
                self._buffer.append('#' * int(tag[1]) + ' ')

    def handle_endtag(self, tag):
        if tag in self.SKIP:
            self._skip = max(0, self._skip - 1)
            return
        if self._skip:
            return
        if tag in ('td', 'th') and self._in_table and self._cell is not None:
            self._row.append(re.sub(r'\s+', ' ', ''.join(self._cell)).strip())
            self._cell = None
        elif tag == 'tr' and self._in_table:
            if any(c for c in self._row):
                self._rows.append(self._row)
            self._row = []
        elif tag == 'table' and self._in_table:
            self._in_table -= 1
            if self._in_table == 0 and self._rows:
                self.blocks.append(_TABLE_MARK + _render_rows(self._rows))
                self._rows = []
        elif tag in self.BLOCKS:
            self._flush()

    def handle_data(self, data):
        if self._skip:
            return
        if self._cell is not None:
            self._cell.append(data)
        else:
            self._buffer.append(data)


_TABLE_MARK = '\x00'


def _render_rows(rows: list[list[str]]) -> str:
    width = max(len(r) for r in rows)
    rows = [r + [''] * (width - len(r)) for r in rows]
    out = ['| ' + ' | '.join(rows[0]) + ' |']
    out.append('|' + '|'.join([' --- '] * width) + '|')
    for r in rows[1:]:
        out.append('| ' + ' | '.join(r) + ' |')
    return '\n'.join(out)


def html_to_markdown(text: str) -> list[str]:
    parser = _TextCollector()
    parser.feed(text)
    parser.close()
    parser._flush()
    out: list[str] = []
    for block in parser.blocks:
        if block.startswith(_TABLE_MARK):
            if out and out[-1] != '':
                out.append('')
            out.extend(block[len(_TABLE_MARK):].split('\n'))
            out.append('')
        else:
            out.append(block)
            out.append('')
    while out and out[-1] == '':
        out.pop()
    return out


def convert_csv(path: Path) -> Path:
    with path.open(encoding='utf-8-sig', newline='') as handle:
        rows = [[_cell(c) for c in row] for row in csv.reader(handle)]
    lines = [
        f"# {path.name}",
        "",
        f"Extraido de `{path.name}` para poder leerlo sin herramienta de hoja de calculo.",
        f"Filas de datos: {max(0, len(rows) - 1)} ademas de la cabecera.",
        "",
    ]
    lines.extend(_table(rows))
    target = path.with_suffix('.md')
    target.write_text("\n".join(lines), encoding='utf-8')
    return target


def convert_html(path: Path) -> Path:
    body = html_to_markdown(path.read_text(encoding='utf-8'))
    lines = [
        f"# {path.name}",
        "",
        f"Texto visible extraido de `{path.name}`. Se omiten estilos y etiquetas;",
        "el contenido y su orden son los del documento.",
        "",
    ]
    lines.extend(body)
    lines.append('')
    target = path.with_suffix('.md')
    target.write_text("\n".join(lines), encoding='utf-8')
    return target


def convert_json(path: Path) -> Path:
    data = json.loads(path.read_text(encoding='utf-8'))
    lines = [
        f"# {path.name}",
        "",
        f"Contenido completo de `{path.name}`, formateado para leerlo en git.",
        "",
        "```json",
        json.dumps(data, ensure_ascii=False, indent=2),
        "```",
        "",
    ]
    target = path.with_suffix('.md')
    target.write_text("\n".join(lines), encoding='utf-8')
    return target


def convert_pdf(path: Path) -> Path:
    from pypdf import PdfReader

    reader = PdfReader(str(path))
    lines = [
        f"# {path.name}",
        "",
        f"Texto extraido de `{path.name}`. Las paginas sin texto se marcan;",
        "puede que esten escaneadas y necesiten OCR.",
        "",
    ]
    vacias: list[int] = []
    for numero, pagina in enumerate(reader.pages, start=1):
        texto = (pagina.extract_text() or "").strip()
        lines.append(f"## Pagina {numero}")
        lines.append("")
        if texto:
            lines.append(texto)
        else:
            vacias.append(numero)
            lines.append("_(pagina sin texto extraible)_")
        lines.append("")
    if vacias:
        lines.insert(
            3,
            f"Paginas sin texto: {', '.join(str(n) for n in vacias)} de "
            f"{len(reader.pages)}.",
        )
        lines.insert(4, "")
    target = path.with_suffix('.md')
    target.write_text("\n".join(lines), encoding='utf-8')
    return target


def convert(path: Path) -> Path:
    suffix = path.suffix.lower()
    if suffix == '.csv':
        return convert_csv(path)
    if suffix in ('.html', '.htm'):
        return convert_html(path)
    if suffix == '.json':
        return convert_json(path)
    if suffix == '.pdf':
        return convert_pdf(path)
    if suffix not in ('.xlsx', '.xlsm'):
        raise ValueError(f"extension no soportada: {path.suffix}")
    return convert_xlsx(path)


def convert_xlsx(path: Path) -> Path:
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
    failed = 0
    for name in argv:
        path = Path(name)
        if not path.exists():
            print(f"no existe: {path}", file=sys.stderr)
            failed += 1
            continue
        try:
            target = convert(path)
        except ValueError as error:
            print(f"{path}: {error}", file=sys.stderr)
            failed += 1
            continue
        print(f"{path} -> {target} ({target.stat().st_size} B)")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
