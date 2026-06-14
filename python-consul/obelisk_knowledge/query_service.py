from __future__ import annotations

from dataclasses import asdict
from typing import Any

from .loader import KnowledgeBase
from .matcher import match_meta_flow, rank_metas


class QueryService:
    def __init__(self, knowledge_base: KnowledgeBase):
        self.knowledge_base = knowledge_base

    def match_flow(self, state: dict[str, Any], flow_id_or_name: str) -> dict[str, Any]:
        meta = self.knowledge_base.get_meta(flow_id_or_name)
        if meta is None:
            raise KeyError(f"Unknown meta flow: {flow_id_or_name}")
        return asdict(match_meta_flow(meta, state))

    def rank_flows(self, state: dict[str, Any]) -> dict[str, Any]:
        results = rank_metas(self.knowledge_base.metas, state)
        return {
            "best_match": results[0].meta_id if results else None,
            "matches": [asdict(item) for item in results],
        }

    def answer(self, question: str, state: dict[str, Any]) -> dict[str, Any]:
        flow = self._detect_flow(question)
        if flow is not None:
            return {
                "query": question,
                "mode": "single_flow_match",
                "result": self.match_flow(state, flow),
            }
        ranked = self.rank_flows(state)
        ranked["query"] = question
        ranked["mode"] = "flow_ranking"
        return ranked

    @staticmethod
    def _detect_flow(question: str) -> str | None:
        lowered = question.lower()
        aliases = {
            "小马": "meta_xiaoma_flow",
            "xiaoma": "meta_xiaoma_flow",
            "学院": "meta_campus_flow",
            "campus": "meta_campus_flow",
            "商路": "meta_trade_route_flow",
            "trade": "meta_trade_route_flow",
        }
        for keyword, flow_id in aliases.items():
            if keyword in lowered:
                return flow_id
        return None
