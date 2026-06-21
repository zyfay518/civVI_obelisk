from __future__ import annotations

import re
from typing import Any


def map_obelisk_snapshot_to_state(
    snapshot: dict[str, Any],
    *,
    desired_victory: str = "General",
) -> dict[str, Any]:
    trade_route_active = _to_int(_first(snapshot, "tradeRouteActive", "trade_route_active"), 0)
    trade_route_capacity = _to_int(_first(snapshot, "tradeRouteCapacity", "trade_route_capacity"), 0)
    trade_route_unused = _first(snapshot, "tradeRouteUnused", "trade_route_unused")
    if trade_route_unused is None:
        trade_route_unused = max(0, trade_route_capacity - trade_route_active)

    at_war_count = _to_int(_first(snapshot, "atWarCount", "at_war_count"), 0)
    resources = _extract_resources(snapshot)
    faith_per_turn = _to_number(_first(snapshot, "faithPerTurn", "faith_per_turn"), 0)
    faith_balance = _to_number(_first(snapshot, "faithBalance", "faith_balance"), 0)
    tourism = _to_number(_first(snapshot, "tourism"), 0)
    gold_per_turn = _to_number(_first(snapshot, "goldPerTurn", "gold_per_turn"), 0)

    return {
        "turn": _to_int(_first(snapshot, "turn"), 0),
        "era": _normalize_era(_first(snapshot, "eraName", "era", "era_name")),
        "city_count": _to_int(_first(snapshot, "cityCount", "city_count"), 0),
        "science": _to_number(_first(snapshot, "science"), 0),
        "culture": _to_number(_first(snapshot, "culture"), 0),
        "gold_per_turn": gold_per_turn,
        "faith_per_turn": faith_per_turn,
        "faith_balance": faith_balance,
        "tourism": tourism,
        "support_economy": int(gold_per_turn >= 10 or faith_per_turn >= 10),
        "military_strength": _to_number(
            _first(snapshot, "militaryStrength", "military_strength"),
            0,
        ),
        "major_contacts": _to_int(_first(snapshot, "majorContacts", "major_contacts"), 0),
        "minor_contacts": _to_int(_first(snapshot, "minorContacts", "minor_contacts"), 0),
        "at_war_count": at_war_count,
        "barbarian_or_war_risk": bool(at_war_count > 0 or _first(snapshot, "barbarianCampCount")),
        "desired_victory": desired_victory,
        "current_tech": _first(snapshot, "currentTech", "current_tech", default="-"),
        "current_civic": _first(snapshot, "currentCivic", "current_civic", default="-"),
        "religion_summary": _first(snapshot, "religionSummary", "religion_summary", default="-"),
        "district_count": _to_int(_first(snapshot, "districtCount", "district_count"), 0),
        "victory_metric_samples": _first(
            snapshot,
            "victoryMetricSamples",
            "victory_metric_samples",
            default=[],
        ),
        "resources": resources,
        "trade_route_active": trade_route_active,
        "trade_route_capacity": trade_route_capacity,
        "trade_route_unused": _to_int(trade_route_unused, 0),
        "average_city_production": _average_city_production(snapshot),
        "strategic_map": {
            "expansion_candidates": _to_int(
                _first(snapshot, "expansionCandidateCount", "expansion_candidate_count"),
                0,
            ),
            "border_pressure": _to_int(
                _first(snapshot, "borderPressureCount", "border_pressure_count"),
                0,
            ),
            "score": _to_int(_first(snapshot, "strategicMapScore", "strategic_map_score"), 0),
        },
    }


def _first(data: dict[str, Any], *keys: str, default: Any = None) -> Any:
    for key in keys:
        if key in data and data[key] is not None:
            return data[key]
    return default


def _to_number(value: Any, default: float) -> float:
    if isinstance(value, bool):
        return default
    if isinstance(value, (int, float)):
        return value
    if isinstance(value, str):
        match = re.search(r"-?\d+(?:\.\d+)?", value)
        if match:
            return float(match.group(0))
    return default


def _to_int(value: Any, default: int) -> int:
    return int(_to_number(value, default))


def _normalize_era(value: Any) -> str:
    text = str(value or "").strip()
    lowered = text.lower()
    mappings = [
        (("ancient", "远古"), "远古"),
        (("classical", "古典"), "古典"),
        (("medieval", "中世纪"), "中世纪"),
        (("renaissance", "文艺复兴"), "文艺复兴"),
        (("industrial", "工业"), "工业"),
        (("modern", "现代"), "现代"),
        (("atomic", "原子"), "原子"),
        (("information", "信息"), "信息"),
        (("future", "未来"), "未来"),
    ]
    for aliases, normalized in mappings:
        if any(alias in lowered or alias in text for alias in aliases):
            return normalized
    return text or "未知"


def _extract_resources(snapshot: dict[str, Any]) -> dict[str, int]:
    horses = _to_int(_first(snapshot, "horses", "horseCount", "horse_count"), 0)
    iron = _to_int(_first(snapshot, "iron", "ironCount", "iron_count"), 0)
    samples = _first(snapshot, "resourceSamples", "resource_samples", default=[]) or []

    for sample in samples:
        text = str(sample)
        amount = _last_number(text, 1)
        lowered = text.lower()
        if "horse" in lowered or "马" in text:
            horses = max(horses, amount)
        if "iron" in lowered or "铁" in text:
            iron = max(iron, amount)

    return {
        "horses": horses,
        "iron": iron,
        "strategic_total": horses + iron,
    }


def _last_number(text: str, default: int) -> int:
    matches = re.findall(r"-?\d+", text)
    if not matches:
        return default
    return int(matches[-1])


def _average_city_production(snapshot: dict[str, Any]) -> float:
    cities = _first(snapshot, "cities", default=[]) or []
    values: list[float] = []
    for city in cities:
        if not isinstance(city, dict):
            continue
        yields = city.get("yields") if isinstance(city.get("yields"), dict) else {}
        production = _first(city, "productionPerTurn", "production_per_turn")
        if production is None:
            production = yields.get("production")
        if production is not None:
            values.append(_to_number(production, 0))
    if values:
        return round(sum(values) / len(values), 2)
    return _to_number(_first(snapshot, "averageCityProduction", "average_city_production"), 0)
