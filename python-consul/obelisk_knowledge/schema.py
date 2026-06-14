from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class RuleEntry:
    id: str
    title: str
    category: str
    summary: str
    observed_state_keys: list[str] = field(default_factory=list)
    explanation_template: str = ""
    raw: dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "RuleEntry":
        return cls(
            id=str(data["id"]),
            title=str(data.get("title") or data.get("name") or data["id"]),
            category=str(data.get("category") or data.get("mechanics", ["general"])[0]),
            summary=str(data.get("summary", "")),
            observed_state_keys=list(data.get("observed_state_keys", [])),
            explanation_template=str(data.get("explanation_template", "")),
            raw=data,
        )


@dataclass(frozen=True)
class Condition:
    id: str
    description: str
    state_key: str
    operator: str
    value: Any
    weight: int = 0
    required: bool = False
    severity: str = "warning"
    visible_in_game: str = ""

    @classmethod
    def from_dict(cls, data: dict[str, Any], default_id: str) -> "Condition":
        return cls(
            id=str(data.get("id", default_id)),
            description=str(data.get("description", "")),
            state_key=str(data.get("state_key", "")),
            operator=str(data.get("operator", "==")),
            value=data.get("value"),
            weight=int(data.get("weight", 0) or 0),
            required=bool(data.get("required", False)),
            severity=str(data.get("severity", "warning")),
            visible_in_game=str(data.get("visible_in_game", "")),
        )


@dataclass(frozen=True)
class MetaFlow:
    id: str
    name: str
    core_goal: str
    key_prerequisites: list[Condition]
    state_match_conditions: list[Condition]
    bad_fit_conditions: list[Condition]
    transition_conditions: list[dict[str, Any]]
    common_failure_reasons: list[str]
    recommended_game_data: list[str]
    player_explanation_template: str
    raw: dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "MetaFlow":
        prerequisites = [
            Condition.from_dict(item, f"{data['id']}_prereq_{index}")
            for index, item in enumerate(data.get("key_prerequisites", []))
        ]
        match_conditions = [
            Condition.from_dict(item, f"{data['id']}_match_{index}")
            for index, item in enumerate(data.get("state_match_conditions", []))
        ]
        bad_conditions = [
            Condition.from_dict(item, f"{data['id']}_bad_{index}")
            for index, item in enumerate(data.get("bad_fit_conditions", []))
        ]
        return cls(
            id=str(data["id"]),
            name=str(data["name"]),
            core_goal=str(data.get("core_goal", "")),
            key_prerequisites=prerequisites,
            state_match_conditions=match_conditions,
            bad_fit_conditions=bad_conditions,
            transition_conditions=list(data.get("transition_conditions", [])),
            common_failure_reasons=list(data.get("common_failure_reasons", [])),
            recommended_game_data=list(data.get("recommended_game_data", [])),
            player_explanation_template=str(data.get("player_explanation_template", "")),
            raw=data,
        )


@dataclass(frozen=True)
class ConditionEvidence:
    id: str
    description: str
    state_key: str
    expected: Any
    actual: Any
    visible_in_game: str
    weight: int = 0
    severity: str = "info"


@dataclass(frozen=True)
class MatchResult:
    meta_id: str
    name: str
    score: int
    fit_level: str
    is_recommended: bool
    matched_conditions: list[ConditionEvidence]
    failed_conditions: list[ConditionEvidence]
    blocking_reasons: list[str]
    next_requirements: list[str]
    recommended_game_data: list[str]
    explanation: str
