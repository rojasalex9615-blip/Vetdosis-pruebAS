#!/usr/bin/env bash
# Verifica tablas y conteos del modulo porcino en el proyecto Supabase de Pruebas.
#
# Uso:
#   export SUPABASE_URL="https://wtrelwtztkddfktrfdpb.supabase.co"
#   export SUPABASE_SECRET_KEY="sb_secret_..."      # para listar esquema y contar
#   bash tools/verify_porcino_counts.sh
#
# Solo LEE (GET). No escribe ni aplica SQL. Si falta la clave, avisa y no inventa.
#
# Por que clave secreta: el catalogo OpenAPI (GET /rest/v1/) y las tablas
# produccion_* solo responden a una clave secreta. La publicable (sb_publishable_)
# responde 401 "Secret API key required" en esas rutas; sirve para auth/v1.

set -u
: "${SUPABASE_URL:?Falta SUPABASE_URL}"
clave="${SUPABASE_SECRET_KEY:-${SUPABASE_PUBLISHABLE_KEY:-}}"
: "${clave:?Falta SUPABASE_SECRET_KEY (o SUPABASE_PUBLISHABLE_KEY como ultimo recurso)}"

api="${SUPABASE_URL%/}/rest/v1"
hdr=(-H "apikey: ${clave}" -H "Authorization: Bearer ${clave}")

# Conteo exacto de una tabla (Content-Range 0-0/N). Imprime total o motivo.
count() {
  local table="$1" headers total code
  headers=$(curl -s -D - -o /dev/null --max-time 25 \
    "${hdr[@]}" -H "Prefer: count=exact" -H "Range: 0-0" \
    "${api}/${table}?select=*")
  code=$(printf '%s\n' "$headers" | head -1 | grep -oE '[0-9]{3}' | head -1)
  total=$(printf '%s\n' "$headers" | grep -i '^content-range:' | grep -oE '/[0-9]+' | tr -d '/')
  if [ -n "$total" ]; then
    echo "total=$total"
  elif [ "$code" = "404" ]; then
    echo "HTTP 404 · no existe o sin permiso"
  elif [ "$code" = "401" ] || [ "$code" = "403" ]; then
    echo "HTTP $code · clave invalida o sin permiso"
  else
    echo "HTTP ${code:-?} · sin Content-Range"
  fi
}

# 1) Lista las tablas visibles desde el esquema OpenAPI de PostgREST.
echo "== Tablas visibles en el esquema =="
schema=$(curl -s --max-time 25 "${hdr[@]}" "${api}/")
if printf '%s' "$schema" | grep -q 'Secret API key required'; then
  echo "  La clave no es secreta. Este endpoint exige sb_secret_."
  exit 1
fi
if [ -z "$schema" ]; then
  echo "  No hubo respuesta. Revisa SUPABASE_URL y la clave."
  exit 1
fi
tables=$(printf '%s' "$schema" | grep -oE '"/[A-Za-z0-9_]+"' | tr -d '"/' | sort -u)
if [ -z "$tables" ]; then
  echo "  La clave respondio, pero no expone tablas."
  printf '%s\n' "$schema" | head -c 400; echo
  exit 1
fi

# 2) Tablas porcinas reales: el esquema aplicado usa produccion_* y lotes_produccion.
echo
echo "== Tablas porcinas aplicadas (esquema produccion_* / lotes_produccion) =="
for t in produccion_especies produccion_especies_propositos produccion_metricas \
         lotes_produccion produccion_registros produccion_eventos; do
  printf '  %-32s %s\n' "$t" "$(count "$t")"
done

# 3) Conteos historicos que cito Ale: viven en esquemas privados (vetdosis_reference_staging,
#    private) que PostgREST NO expone ("Only the following schemas are exposed: public,
#    graphql_public"). Se reporta lo que la API responda, sin inventar.
echo
echo "== Conteos citados por Ale (esquema public; los privados no son alcanzables por PostgREST) =="
declare -A esperado=(
  [productos_staging]=1384
  [pautas_comerciales]=217
  [vetdosis_qwen_farmacos_revision]=106
  [vetdosis_qwen_marcas_revision]=30
  [vetdosis_qwen_dosis_revision]=19
)
for t in "${!esperado[@]}"; do
  printf '  %-34s %s  (citado: %s)\n' "$t" "$(count "$t")" "${esperado[$t]}"
done
echo "  Nota: esas tablas estan en vetdosis_reference_staging / private, no en public."
echo "  Para contarlas hace falta SQL directo (psql/DB URL), no PostgREST."

echo
echo "Nota: HTTP 200/206 = respondio; 404 = no existe o sin permiso; 401/403 = clave invalida."
