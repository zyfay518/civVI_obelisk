from __future__ import annotations

from typing import Any

from .schema import Condition, ConditionEvidence, MatchResult, MetaFlow
from .scorer import MISSING, condition_matches


def _actual_to_text(value: Any) -> Any:
    return "<missing>" if value is MISSING else value


def _evidence(condition: Condition, actual: Any, severity: str = "info") -> ConditionEvidence:
    return ConditionEvidence(
        id=condition.id,
        description=condition.description,
        state_key=condition.state_key,
        expected={condition.operator: condition.value},
        actual=_actual_to_text(actual),
        visible_in_game=condition.visible_in_game,
        weight=condition.weight,
        severity=severity,
    )


def _fit_level(score: int, blocking_reasons: list[str]) -> str:
    if blocking_reasons:
        return "poor"
    if score >= 75:
        return "strong"
    if score >= 50:
        return "conditional"
    if score >= 30:
        return "weak"
    return "poor"


def match_meta_flow(meta: MetaFlow, state: dict[str, Any]) -> MatchResult:
    max_score = 0
    raw_score = 0
    matched: list[ConditionEvidence] = []
    failed: list[ConditionEvidence] = []
    blocking_reasons: list[str] = []
    next_requirements: list[str] = []

    for condition in [*meta.key_prerequisites, *meta.state_match_conditions]:
        max_score += max(condition.weight, 0)
        ok, actual = condition_matches(condition, state)
        if ok:
            raw_score += max(condition.weight, 0)
            matched.append(_evidence(condition, actual))
        else:
            failed.append(_evidence(condition, actual, "warning"))
            next_requirements.append(condition.description)
            if condition.required:
                blocking_reasons.append(condition.description)

    for condition in meta.bad_fit_conditions:
        bad, actual = condition_matches(condition, state)
        if bad:
            failed.append(_evidence(condition, actual, condition.severity))
            next_requirements.append(condition.description)
            if condition.severity == "blocking":
                blocking_reasons.append(condition.description)

    score = int(round((raw_score / max_score) * 100)) if max_score else 0
    if blocking_reasons:
        score = min(score, 35)

    fit_level = _fit_level(score, blocking_reasons)
    is_recommended = fit_level in {"strong", "conditional"}
    explanation = build_explanation(meta, score, fit_level, matched, failed, blocking_reasons)

    return MatchResult(
        meta_id=meta.id,
        name=meta.name,
        score=score,
        fit_level=fit_level,
        is_recommended=is_recommended,
        matched_conditions=matched,
        failed_conditions=failed,
        blocking_reasons=blocking_reasons,
        next_requirements=list(dict.fromkeys(next_requirements)),
        recommended_game_data=meta.recommended_game_data,
        explanation=explanation,
    )


def build_explanation(
    meta: MetaFlow,
    score: int,
    fit_level: str,
    matched: list[ConditionEvidence],
    failed: list[ConditionEvidence],
    blocking_reasons: list[str],
) -> str:
    if blocking_reasons:
        return f"{meta.name}当前不适合，评分 {score}。主要阻断原因：{'；'.join(blocking_reasons)}。"
    if fit_level == "strong":
        return f"{meta.name}当前适配度较高，评分 {score}。核心条件基本成立，但仍应由玩家决定是否执行。"
    if fit_level == "conditional":
        warnings = "；".join(item.description for item in failed[:2]) or "仍需确认执行窗口"
        return f"{meta.name}当前有条件适合，评分 {score}。需要重点确认：{warnings}。"
    return f"{meta.name}当前适配度偏低，评分 {score}。建议先补齐关键条件，再考虑该流派。"


def rank_metas(metas: list[MetaFlow], state: dict[str, Any]) -> list[MatchResult]:
    return sorted(
        (match_meta_flow(meta, state) for meta in metas),
        key=lambda item: item.score,
        reverse=True,
    )
