from __future__ import annotations

import json
import unittest
from pathlib import Path

from obelisk_knowledge.loader import load_knowledge_base
from obelisk_knowledge.query_service import QueryService


REPO_ROOT = Path(__file__).resolve().parents[2]
KNOWLEDGE_ROOT = REPO_ROOT / "knowledge"


def load_state(name: str) -> dict:
    return json.loads((KNOWLEDGE_ROOT / "mock_states" / name).read_text(encoding="utf-8"))


class KnowledgeMatcherTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.kb = load_knowledge_base(KNOWLEDGE_ROOT)
        cls.service = QueryService(cls.kb)

    def test_loads_rules_and_metas(self) -> None:
        self.assertGreaterEqual(len(self.kb.rules), 10)
        self.assertEqual(len(self.kb.metas), 3)

    def test_xiaoma_flow_scores_well_when_horses_exist(self) -> None:
        result = self.service.match_flow(load_state("early_horse_state.json"), "小马流")
        self.assertEqual(result["meta_id"], "meta_xiaoma_flow")
        self.assertGreaterEqual(result["score"], 60)
        self.assertIn(result["fit_level"], {"strong", "conditional"})
        self.assertTrue(result["matched_conditions"])

    def test_xiaoma_flow_blocks_without_horses(self) -> None:
        result = self.service.match_flow(load_state("weak_horse_state.json"), "小马流")
        self.assertLessEqual(result["score"], 35)
        self.assertEqual(result["fit_level"], "poor")
        self.assertTrue(result["blocking_reasons"])

    def test_ranks_campus_for_science_state(self) -> None:
        result = self.service.rank_flows(load_state("campus_state.json"))
        self.assertEqual(result["best_match"], "meta_campus_flow")
        self.assertEqual(result["matches"][0]["name"], "学院流")

    def test_answer_detects_specific_flow(self) -> None:
        result = self.service.answer("我现在适合玩小马流吗？", load_state("early_horse_state.json"))
        self.assertEqual(result["mode"], "single_flow_match")
        self.assertEqual(result["result"]["meta_id"], "meta_xiaoma_flow")

    def test_answer_can_rank_flows(self) -> None:
        result = self.service.answer("我现在更适合哪个流派？", load_state("campus_state.json"))
        self.assertEqual(result["mode"], "flow_ranking")
        self.assertIn("matches", result)


if __name__ == "__main__":
    unittest.main()
