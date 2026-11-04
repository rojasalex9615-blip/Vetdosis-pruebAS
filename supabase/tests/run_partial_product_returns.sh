#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
PARTIAL_PRODUCT_RETURNS=1 bash supabase/tests/run_service_commission_recoveries.sh \
 supabase/migrations/20261027024532_partial_product_returns.sql \
 supabase/tests/partial_product_returns.sql "$@"
