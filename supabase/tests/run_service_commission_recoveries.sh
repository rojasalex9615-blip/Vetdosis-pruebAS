#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
SERVICE_COMMISSION_RECOVERIES=1 bash supabase/tests/run_permission_clinic_operations.sh \
 supabase/proposed/13B5_service_commission_settlements.sql \
 supabase/proposed/13B6_service_commission_fk_indexes.sql \
 supabase/tests/service_commission_settlements.sql \
 supabase/migrations/20261027021257_service_commission_recoveries.sql \
 supabase/tests/service_commission_recoveries.sql
