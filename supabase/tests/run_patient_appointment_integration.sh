#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
# Existing focused fixtures have their own schemas and cluster roles.
# Keep each fixture isolated while validating the exact integrated SQL files.
container_name=''
trap 'if [ -n "$container_name" ]; then docker rm -f "$container_name" >/dev/null; fi' EXIT
for fixture in history_booklet_validation patient_activity_snapshot appointment_care patient_contacts_links preventive_booklet_v2; do
 container_name="vetdosis-patient-links-$$-$fixture"
 docker run -d --name "$container_name" --network none -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17-alpine >/dev/null
 ready=false
 for attempt in {1..30}; do
  if docker exec "$container_name" pg_isready -h 127.0.0.1 -U postgres >/dev/null 2>&1; then ready=true;break;fi
  sleep 1
 done
 if [ "$ready" != true ];then echo 'PostgreSQL startup failed';exit 1;fi
 docker exec "$container_name" mkdir /repo
 docker cp supabase "$container_name:/repo/" >/dev/null
 docker exec "$container_name" psql -U postgres -v ON_ERROR_STOP=1 -f "/repo/supabase/tests/$fixture.sql"
 docker rm -f "$container_name" >/dev/null
 container_name=''
 echo "Passed integrated patient/appointment fixture: $fixture"
done
