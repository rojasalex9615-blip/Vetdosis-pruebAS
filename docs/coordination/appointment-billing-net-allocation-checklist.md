# Appointment billing net allocation — validation package

Status: investigation only. This document is not a production migration.

Target function:
- `public.appointment_patient_links(uuid, uuid[])`
- Existing migration: `supabase/adaptations/appointment_patient_billing_collections_v2.sql`

Reference contract observed in the Supabase test project:
- `private.sale_balance(p_sale, p_clinic)` reports `net_total = sale.total - sum(return.amount)`.
- For sales with a credit account, `paid` is the sum of collections; for non-credit POS sales, `paid = sale.total`.
- `balance = greatest(net_total - paid + refunded, 0)`.
- Therefore the effective retained/applied payment should be derived consistently from net total and balance; raw collections alone are not sufficient for a mixed sale after a product return.

## Required behavior tests

1. Mixed sale: service $60 + product $40; collection $60; return product $40; refund $0. Appointment billing should show service total $60, paid $60, balance $0, state `paid`.
2. Rounding: three service lines of $33.33; collection $1.00. Allocated cents must sum exactly to $1.00 (never $0.99).
3. Service/product return with cash refund: paid allocation must reflect the refund and not claim the refunded amount is still retained.
4. Fully paid POS sale without a credit account: linked service acts must not be shown unpaid just because there is no collection row.
5. Sequence collection → return → collection: current state must match the sale ledger and must not double-count or lose cents.
6. Reversed sale: exclude reversed sale lines and payments from appointment billing.
7. Appointment service act without a linked sale line: preserve the established legacy behavior, or explicitly document the intended replacement before changing it.
8. Multiple service lines and multiple sales linked to the same appointment: allocation totals must be deterministic and sum to the ledger amount.

## Safety and release gates

- Do not run this as a remote migration until the replacement function and tests are reviewed.
- Do not change historical return, collection, or sale records to repair a read-model allocation bug.
- Run SQL tests against the same PostgreSQL major version as CI (currently PostgreSQL 17); scratch PostgreSQL 16 results alone are insufficient.
- Run the focused Supabase SQL tests, then the full SQL suite and Flutter tests for the integration commit.
- Keep the fix isolated on `fix/appointment-billing-net-allocation-20261031`; do not merge PR #77 while conflicts remain or until required checks pass.
- No production migration, merge, or APK release is authorized by this checklist.

## Current implementation draft (2026-10-30)

The isolated SQL draft now:
- Reconciles each sale's net total, collections (or POS-paid status), and recorded refunds before allocating payment.
- Allocates payment over all remaining sale lines, including product lines, so a product return changes the denominator correctly.
- Uses cumulative rounded allocations in stable line-ID order so per-line cent rounding sums to the sale-level allocation.
- Keeps reversed sales excluded and does not mutate historical ledger rows.

Regression coverage added to `supabase/tests/patient_contacts_links.sql`:
- Mixed service/product sale with product returned and no cash refund.
- Three $33.33 service lines with a $1.00 collection, asserting the appointment reports the full $1.00 allocation.
- Added a POS regression for a fully paid sale without a credit account or collection row.
- Corrected a malformed DO-block opener and the POS fixture's clinic ID.

Validation status:
- Changes are committed only to the isolated branch.
- SQL execution has **not** yet been run against PostgreSQL 17 or the Supabase test project; these are regression expectations, not passing test results.
- Before remote application, still verify schema compatibility, POS sale behavior, return/refund sequences, multiple sales, unlinked service acts, and the full SQL/Flutter suites.
