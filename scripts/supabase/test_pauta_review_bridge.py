import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SQL = (ROOT / 'supabase/proposed/16D_pauta_review_bridge.sql').read_text().lower()


class PautaReviewBridgeGuards(unittest.TestCase):
    def test_key_is_row_key_not_id_pauta(self):
        # id_pauta tiene dos duplicados exactos en el lote; row_key es único.
        self.assertIn("'grok_pautas:'||r.row_key", SQL)
        self.assertNotIn("original_payload->>'id_pauta'", SQL.split('create or replace function public.review_pauta_list')[1].split('$$;')[0])

    def test_read_returns_the_screen_shape(self):
        # La pantalla no cambia: review_pauta_list devuelve lo mismo que
        # review_catalog_list, incluidos los tres estados.
        body = SQL.split('create or replace function public.review_pauta_list')[1]
        for column in (
            'source_key text, catalog_version text, title text, laboratory text',
            'global_review_status text, clinic_review_status text, personal_review_status text',
        ):
            self.assertIn(column, body)

    def test_all_three_writes_accept_the_pauta_source(self):
        for fn in (
            'review_catalog_set_status',
            'review_catalog_set_personal_status',
            'review_catalog_set_global_status',
        ):
            body = SQL.split('function public.' + fn)[1].split('$$;')[0]
            # Clínica y personal comparan la clave; global ya divide la fuente.
            self.assertTrue(
                "p_source_key like 'grok_pautas:%'" in body
                or "v_source = 'grok_pautas'" in body,
                fn,
            )

    def test_global_state_has_its_own_table(self):
        # El catálogo comercial guarda el estado global en su propia tabla; las
        # pautas no la tienen, así que necesitan una.
        self.assertIn('create table if not exists private.catalog_review_global_status', SQL)

    def test_state_tables_admit_the_new_source(self):
        self.assertEqual(
            SQL.count("check (source_catalog in ('inventario_comercial','grok_pautas'))"),
            5,
        )

    def test_unknown_key_and_status_are_still_rejected(self):
        self.assertIn("raise exception 'review_item_not_found'", SQL)
        self.assertIn("raise exception 'invalid_review_status'", SQL)
        self.assertIn("raise exception 'review_access_denied'", SQL)

    def test_no_calculation_rule_is_enabled(self):
        # Revisar no activa cálculo: la lista sigue devolviendo enabled_in_app=false.
        self.assertNotIn('enabled_in_app=true', SQL.replace(' ', ''))
        self.assertIn('false, p.snapshot', SQL)

    def test_reapplying_changes_nothing(self):
        self.assertNotIn('create function public.', SQL)
        self.assertNotIn('create function private.', SQL)


if __name__ == '__main__':
    unittest.main()
