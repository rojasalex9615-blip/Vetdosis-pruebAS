#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
INSTALLMENTS_SERVICE_RETURNS=1 bash supabase/tests/run_partial_product_returns.sh \
 supabase/proposed/14D_admin_service_commissions.sql \
 supabase/proposed/14F_catalog_service_sale_price.sql \
 supabase/migrations/20261027031218_installments_service_returns.sql \
 supabase/tests/installments_service_returns.sql
