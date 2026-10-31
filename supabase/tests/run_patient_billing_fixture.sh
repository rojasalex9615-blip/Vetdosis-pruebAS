#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
container_name="vetdosis-billing-fixture-$$"
trap 'docker rm -f "$container_name" >/dev/null 2>&1 || true' EXIT
docker run -d --name "$container_name" --network none -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17-alpine >/dev/null
ready=false
for attempt in {1..30}; do
  if docker exec "$container_name" pg_isready -h 127.0.0.1 -U postgres >/dev/null 2>&1; then ready=true; break; fi
  sleep 1
done
if [ "$ready" != true ]; then echo 'PostgreSQL startup failed' >&2; exit 1; fi
docker exec "$container_name" mkdir /repo
docker cp supabase "$container_name:/repo/" >/dev/null
docker exec "$container_name" psql -U postgres -v ON_ERROR_STOP=1 -f /repo/supabase/tests/patient_contacts_links.sql
docker rm -f "$container_name" >/dev/null
trap - EXIT
echo "Passed isolated PostgreSQL 17 patient/appointment billing fixture"
