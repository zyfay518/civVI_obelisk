from __future__ import annotations

import json
import unittest
from pathlib import Path

from obelisk_knowledge.answer_builder import build_ai_context, build_player_answer
from obelisk_knowledge.loader import load_knowledge_base
from obelisk_knowledge.local_service import ConsulApplication
from obelisk_knowledge.query_service import QueryService
from obelisk_knowledge.state_mapper import map_obelisk_snapshot_to_state


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
        self.assertGreaterEqual(len(self.kb.metas), 8)

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

    def test_maps_obelisk_snapshot_to_standard_state(self) -> None:
        snapshot = {
            "turn": 48,
            "eraName": "古典时代",
            "cityCount": 3,
            "science": 18,
            "culture": 12,
            "goldPerTurn": 9,
            "militaryStrength": 104,
            "majorContacts": 2,
            "minorContacts": 1,
            "atWarCount": 0,
            "currentTech": "骑马",
            "resourceSamples": ["马 2", "铁 0"],
            "tradeRouteActive": 1,
            "tradeRouteCapacity": 2,
            "cities": [
                {"name": "首都", "yields": {"production": 7}},
                {"name": "二城", "yields": {"production": 5}},
            ],
            "expansionCandidateCount": 4,
            "borderPressureCount": 1,
        }

        state = map_obelisk_snapshot_to_state(snapshot)

        self.assertEqual(state["era"], "古典")
        self.assertEqual(state["city_count"], 3)
        self.assertEqual(state["resources"]["horses"], 2)
        self.assertEqual(state["resources"]["strategic_total"], 2)
        self.assertEqual(state["trade_route_unused"], 1)
        self.assertEqual(state["average_city_production"], 6)
        self.assertFalse(state["barbarian_or_war_risk"])

    def test_query_service_accepts_mapped_obelisk_snapshot(self) -> None:
        state = map_obelisk_snapshot_to_state(
            {
                "turn": 42,
                "eraName": "古典时代",
                "cityCount": 2,
                "science": 14,
                "culture": 9,
                "goldPerTurn": 8,
                "militaryStrength": 95,
                "majorContacts": 1,
                "minorContacts": 1,
                "atWarCount": 0,
                "resourceSamples": ["马 1"],
                "tradeRouteActive": 0,
                "tradeRouteCapacity": 1,
                "cities": [{"yields": {"production": 6}}],
            }
        )

        result = self.service.answer("我现在适合玩小马流吗？", state)

        self.assertEqual(result["mode"], "single_flow_match")
        self.assertEqual(result["result"]["meta_id"], "meta_xiaoma_flow")
        self.assertGreaterEqual(result["result"]["score"], 60)

    def test_detects_new_strategy_aliases(self) -> None:
        state = {
            "turn": 90,
            "era": "中世纪",
            "city_count": 4,
            "science": 30,
            "culture": 20,
            "gold_per_turn": 12,
            "faith_per_turn": 4,
            "tourism": 10,
            "military_strength": 180,
            "major_contacts": 2,
            "minor_contacts": 1,
            "at_war_count": 0,
            "average_city_production": 8,
            "desired_victory": "General",
            "support_economy": 1,
            "resources": {"horses": 2, "iron": 1, "strategic_total": 3},
            "strategic_map": {"expansion_candidates": 2},
            "trade_route_capacity": 1,
            "trade_route_unused": 0,
        }

        expectations = {
            "我适合征服流吗？": "meta_conquest_flow",
            "我适合宗教流吗？": "meta_religion_flow",
            "我适合文化流吗？": "meta_culture_flow",
            "我适合工业流吗？": "meta_industry_flow",
            "我适合扩张流吗？": "meta_expansion_flow",
        }
        for question, meta_id in expectations.items():
            with self.subTest(question=question):
                result = self.service.answer(question, state)
                self.assertEqual(result["mode"], "single_flow_match")
                self.assertEqual(result["result"]["meta_id"], meta_id)

    def test_player_answer_contains_explanation_contract(self) -> None:
        raw = self.service.answer("我现在适合玩小马流吗？", load_state("early_horse_state.json"))
        answer = build_player_answer(raw)
        self.assertIn("判断依据", answer["body"])
        self.assertIn("下一步在游戏里看", answer["body"])
        self.assertIn("不是替你直接下指令", answer["body"])

    def test_ai_context_contains_state_and_evidence(self) -> None:
        state = load_state("campus_state.json")
        raw = self.service.answer("我现在更适合哪个流派？", state)
        context = build_ai_context(raw, state)
        self.assertTrue(context["answer_contract"]["must_explain_basis"])
        self.assertIn("visible_state_summary", context)
        self.assertTrue(context["evidence"])

    def test_local_service_accepts_obelisk_payload(self) -> None:
        app = ConsulApplication(str(KNOWLEDGE_ROOT))
        response = app.answer(
            {
                "question": "我现在更适合哪个流派？",
                "state_format": "obelisk",
                "output": "answer",
                "state": {
                    "turn": 70,
                    "eraName": "古典时代",
                    "cityCount": 4,
                    "science": 22,
                    "culture": 16,
                    "goldPerTurn": 14,
                    "faithPerTurn": 2,
                    "militaryStrength": 130,
                    "majorContacts": 2,
                    "minorContacts": 1,
                    "atWarCount": 0,
                    "horseCount": 2,
                    "ironCount": 1,
                    "tradeRouteActive": 1,
                    "tradeRouteCapacity": 2,
                    "cities": [{"yields": {"production": 8}}],
                    "expansionCandidateCount": 3,
                },
            }
        )
        self.assertIn("body", response)
        self.assertIn("当前流派适配排序", response["body"])


if __name__ == "__main__":
    unittest.main()
