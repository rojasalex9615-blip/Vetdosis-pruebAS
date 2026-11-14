#!/usr/bin/env bash
# Verifica tablas y conteos del módulo porcino en el proyecto Supabase de Pruebas.
#
# Uso:
#   export SUPABASE_URL="https://wtrelwtztkddfktrfdpb.supabase.co"
#   export SUPABASE_PUBLISHABLE_KEY="sb_publishable_..."
#   bash tools/verify_porcino_counts.sh
#
# Solo LEE (GET). No escribe ni aplica SQL. Si falta la clave, avisa y no inventa.

set -u
: "${SUPABASE_URL:?Falta SUPABASE_URL}"
: "${SUPABASE_PUBLISHABLE_KEY:?Falta SUPABASE_PUBLISHABLE_KEY (clave publicable, no service_role)}"

api="${SUPABASE_URL%/}/rest/v1"
hdr=(-H "apikey: ${SUPABASE_PUBLISHABLE_KEY}" -H "Authorization: Bearer ${SUPABASE_PUBLISHABLE_KEY}")

# 1) Lista las tablas visibles desde el esquema OpenAPI de PostgREST.
echo "== Tablas visibles en el esquema =="
schema=$(curl -s --max-time 25 "${hdr[@]}" "${api}/")
if [ -z "$schema" ]; then
  echo "  No hubo respuesta. Revisa SUPABASE_URL y la clave."
  exit 1
fi
tables=$(printf '%s' "$schema" \
  | grep -oE '"/[a-z0-9_]+"' | tr -d '"/' | sort -u)
if [ -z "$tables" ]; then
  echo "  La clave respondió, pero no expone tablas (¿RLS/solo auth?)."
  printf '%s\n' "$schema" | head -c 400; echo
  exit 1
fi
printf '%s\n' "$tables" | sed 's/^/  /'

# 2) Conteo exacto de una tabla (Content-Range 0-0/N). Imprime total o motivo.
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
    echo "HTTP $code · clave inválida o sin permiso"
  else
    echo "HTTP ${code:-?} · sin Content-Range"
  fi
}

# 3) Conteos históricos que citó Ale: solo se reporta lo que la API responda.
echo
echo "== Conteos citados por Ale (se compara contra lo que responda la API) =="
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

# 4) Tablas porcinas: se muestran las que existan con nombre porcino_*.
echo
echo "== Tablas porcino_* visibles =="
found=0
for t in $tables; do
  case "$t" in
    porcino_*) printf '  %-24s %s\n' "$t" "$(count "$t")"; found=1 ;;
  esac
done
[ "$found" = 1 ] || echo "  (ninguna)"

echo
echo "Nota: HTTP 200/206 = respondió; 404 = no existe o sin permiso; 401/403 = clave inválida."
