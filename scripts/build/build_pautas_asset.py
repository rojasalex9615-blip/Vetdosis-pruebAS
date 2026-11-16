#!/usr/bin/env python3
"""Genera assets/clinical/manufacturer_pautas.v1.json desde el CSV maestro de pautas de Grok.

Reproducible y sin decisiones clinicas: copia literal de los 35 campos del CSV.
Solo normaliza espacios y calcula avisos de integridad. No inventa ni reescribe dosis.

Uso:
  python3 scripts/build/build_pautas_asset.py ENTRADA.csv SALIDA.json [--compact]
"""
import argparse
import csv
import hashlib
import json
from urllib.parse import urlparse

SOURCE_FILE = "Pautas_VetDosis_MAESTRO.csv"
SOURCE_URL = "https://drive.google.com/file/d/1V60KiE2eBhr9hiRZUc1PeDbK1OJmFaZe/view"
RESEARCHER = "Grok"

FIELD_MAP = [
    ("id", "id_pauta"),
    ("product_name", "nombre_comercial"),
    ("manufacturer", "fabricante"),
    ("product_url", "url_plm"),
    ("presentation", "presentacion_exacta"),
    ("registro", "registro_sanitario"),
    ("ingredients", "principio_activo"),
    ("ingredient_amount", "cantidad_pa"),
    ("ingredient_unit", "unidad_pa"),
    ("ingredient_base", "base_pa"),
    ("species", "especie"),
    ("stage", "categoria_etapa"),
    ("indication", "indicacion"),
    ("age_weight_limits", "restricciones_edad_peso"),
    ("literal", "posologia_literal"),
    ("route", "via"),
    ("dose_amount", "cantidad_admin"),
    ("dose_unit", "unidad_admin"),
    ("dose_reference", "referencia"),
    ("rule", "tipo_regla"),
    ("interval", "intervalo"),
    ("duration", "duracion"),
    ("applications", "num_aplicaciones"),
    ("repeat_conditions", "condiciones_repetir"),
    ("site_max", "maximo_dosis_sitio"),
    ("weight_bands", "bandas_peso"),
    ("tablet_split", "fraccionar_tabletas"),
    ("contraindications", "contraindicaciones"),
    ("withdrawal", "tiempo_retiro"),
    ("evidence_url", "url_evidencia"),
    ("evidence_section", "seccion_pdf"),
    ("consulted_at", "fecha_consulta"),
    ("discrepancies", "discrepancias"),
    ("state", "estado_pauta"),
    ("notes", "notas"),
]

KNOWN_STATES = {
    "Pauta documentada",
    "Identificación verificada – pauta no documentada aún",
    "Conflicto de fuentes",
}
KNOWN_RULES = {
    "proporcional al peso",
    "fija por animal",
    "bandas de peso",
    "agua/alimento",
    "esquema vacunal",
    "otra",
}


def warnings_for(row, seen_ids):
    out = []
    url = (row.get("url_plm") or "").strip()
    host = urlparse(url).hostname if url else None
    if host != "www.diccionarioveterinarioplm.com":
        out.append(f"url_plm fuera del host PLM: {host or 'vacío'}")
    state = (row.get("estado_pauta") or "").strip()
    if state and state not in KNOWN_STATES:
        out.append(f"estado_pauta no reconocido: {state[:60]}")
    rule = (row.get("tipo_regla") or "").strip()
    if rule and rule not in KNOWN_RULES:
        out.append(f"tipo_regla no reconocido: {rule[:60]}")
    pid = (row.get("id_pauta") or "").strip()
    if not pid:
        out.append("id_pauta vacío")
    elif pid in seen_ids:
        out.append("id_pauta duplicado")
    if not (row.get("posologia_literal") or "").strip():
        out.append("sin posologia_literal")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("dest")
    ap.add_argument("--compact", action="store_true")
    ap.add_argument(
        "--emit-intake-sql",
        metavar="BATCH_UUID",
        help="Además del asset, escribe el INSERT de ingesta verbatim para el lote dado.",
    )
    ap.add_argument("--intake-sql", default=None, help="Ruta del SQL de ingesta.")
    args = ap.parse_args()

    raw = open(args.source, "rb").read()
    digest = hashlib.sha256(raw).hexdigest()
    text = raw.decode("utf-8-sig", "replace")
    rows = list(csv.DictReader(text.splitlines(True)))

    seen_ids = set()
    pautas = []
    warned = 0
    for row in rows:
        item = {key: (row.get(col) or "").strip() for key, col in FIELD_MAP}
        warn = warnings_for(row, seen_ids)
        seen_ids.add(item["id"])
        if warn:
            item["warnings"] = warn
            warned += 1
        pautas.append(item)

    pautas.sort(key=lambda p: (p["id"], p["product_url"]))
    product_urls = {p["product_url"] for p in pautas if p["product_url"]}
    asset = {
        "schema_version": 1,
        "source_file": SOURCE_FILE,
        "source_url": SOURCE_URL,
        "source_sha256": digest,
        "researcher": RESEARCHER,
        "pauta_count": len(pautas),
        "product_url_count": len(product_urls),
        "pautas_with_warnings": warned,
        "note": (
            "Copía literal de Pautas_VetDosis_MAESTRO.csv. No es validación clínica: "
            "cada pauta entra sin verificar y requiere revisión MVZ antes de calcular."
        ),
        "pautas": pautas,
    }
    dumped = json.dumps(
        asset,
        ensure_ascii=False,
        indent=None if args.compact else 1,
        separators=(",", ":") if args.compact else None,
    )
    open(args.dest, "w", encoding="utf-8").write(dumped + "\n")
    print(
        f"{len(pautas)} pautas · {len(product_urls)} productos · "
        f"{warned} con avisos · sha256 {digest[:12]}"
    )

    if args.emit_intake_sql:
        batch = args.emit_intake_sql
        dest = args.intake_sql or f"{args.dest}.intake.sql"
        rows_json = json.dumps(
            [
                {
                    **{col: row.get(col, "") for _, col in FIELD_MAP},
                    "_r": str(index + 2),
                }
                for index, row in enumerate(rows)
            ],
            ensure_ascii=False,
        )
        sql = f"""-- CANDIDATO LOCAL, NO APLICADO. Ingesta verbatim del maestro de pautas de Grok.
-- Todo entra con review_state='pending': ninguna pauta es verdad clinica hasta
-- que un MVZ la revise en el modo revision. No se activa ninguna regla de calculo.
-- Idempotente: on conflict (batch_id,row_key) do nothing.
--
-- Revertir:
--   delete from vetdosis_reference_staging.raw_intake_rows where batch_id='{batch}';
--   delete from vetdosis_reference_staging.import_batches  where id='{batch}';

insert into vetdosis_reference_staging.import_batches
  (id,batch_key,label,origin_filename,original_sha256,ingestion_notes)
values ('{batch}','pautas_grok_1197_20261115',
  'Pautas comerciales de Grok: {len(pautas)} filas del maestro de posologia',
  '{SOURCE_FILE}','{digest}',
  'Copia literal de {SOURCE_FILE}. NO es validacion clinica.')
on conflict (id) do nothing;

insert into vetdosis_reference_staging.raw_intake_rows
  (batch_id,row_key,source_filename,source_sheet,source_row,source_title,
   original_payload,row_sha256,review_state,ingestion_note)
select '{batch}', 'pautas_grok_1197_20261115:row:'||(e->>'_r'),
  '{SOURCE_FILE}', 'Pautas', (e->>'_r')::int,
  nullif(left(e->>'id_pauta',400),''), e,
  encode(sha256(convert_to(e::text,'UTF8')),'hex'), 'pending',
  'Imported verbatim; not clinically validated'
from jsonb_array_elements($vd${rows_json}$vd$::jsonb) e
on conflict (batch_id,row_key) do nothing;
"""
        open(dest, "w", encoding="utf-8").write(sql)
        print(f"SQL de ingesta escrito en {dest}")


if __name__ == "__main__":
    main()
