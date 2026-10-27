#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
bash supabase/tests/run_installments_service_returns.sh \
 supabase/migrations/20261027144905_financial_return_freshness.sql \
 supabase/tests/financial_return_freshness.sql
