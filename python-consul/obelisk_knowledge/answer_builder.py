from __future__ import annotations

from typing import Any


def build_player_answer(query_result: dict[str, Any], *, language: str = "zh") -> dict[str, Any]:
    if query_result.get("mode") == "single_flow_match":
        result = query_result["result"]
        return _single_flow_answer(query_result["query"], result, language=language)

    matches = query_result.get("matches", [])
    return _ranking_answer(query_result.get("query", ""), matches, language=language)


def build_ai_context(query_result: dict[str, Any], state: dict[str, Any]) -> dict[str, Any]:
    answer = build_player_answer(query_result)
    evidence = _collect_evidence(query_result)
    return {
        "player_question": query_result.get("query", ""),
        "answer_contract": {
            "must_explain_basis": True,
            "must_not_directly_play_for_user": True,
            "must_include_in_game_data_locations": True,
            "must_surface_uncertainty": True,
        },
        "visible_state_summary": _state_summary(state),
        "knowledge_result": query_result,
        "deterministic_answer": answer,
        "evidence": evidence,
    }


def _single_flow_answer(question: str, result: dict[str, Any], *, language: str) -> dict[str, Any]:
    blockers = result.get("blocking_reasons", [])
    failed = result.get("failed_conditions", [])
    matched = result.get("matched_conditions", [])
    checks = result.get("recommended_game_data", [])

    if language == "zh":
        title = f"{result['name']}：{_fit_text(result)}，评分 {result['score']}/100"
        basis = _join_descriptions(matched) or "核心条件不足，需要更多可见数据确认。"
        risks = "；".join(blockers) or _join_descriptions(failed) or "暂无明显阻断项。"
        next_steps = _format_checks(checks)
        body = (
            f"{title}\n"
            f"判断依据：{basis}\n"
            f"风险/缺口：{risks}\n"
            f"下一步在游戏里看：{next_steps}\n"
            "这是基于当前可见局势的解释，不是替你直接下指令。"
        )
    else:
        title = f"{result['name']}: {_fit_text(result, language='en')}, score {result['score']}/100"
        basis = _join_descriptions(matched) or "Core conditions are not sufficiently visible yet."
        risks = "; ".join(blockers) or _join_descriptions(failed) or "No hard blocker is visible."
        next_steps = _format_checks(checks)
        body = (
            f"{title}\n"
            f"Basis: {basis}\n"
            f"Risks/gaps: {risks}\n"
            f"Check in game: {next_steps}\n"
            "This explains the visible-state judgement; it does not play for you."
        )

    return {
        "question": question,
        "title": title,
        "body": body,
        "fit_level": result.get("fit_level"),
        "score": result.get("score"),
        "recommended": result.get("is_recommended"),
        "next_checks": checks,
    }


def _ranking_answer(question: str, matches: list[dict[str, Any]], *, language: str) -> dict[str, Any]:
    top = matches[:5]
    if language == "zh":
        lines = ["当前流派适配排序："]
        for index, match in enumerate(top, start=1):
            lines.append(f"{index}. {match['name']}：{match['score']}/100，{_fit_text(match)}")
        if top:
            lines.append(f"优先检查第一名的风险项：{_join_descriptions(top[0].get('failed_conditions', [])) or '暂无明显阻断项。'}")
        lines.append("如果要深入，直接问某个流派为什么适合或不适合。")
        title = "当前流派排序"
    else:
        lines = ["Current strategy ranking:"]
        for index, match in enumerate(top, start=1):
            lines.append(f"{index}. {match['name']}: {match['score']}/100, {_fit_text(match, language='en')}")
        if top:
            lines.append(f"First check the top route's risks: {_join_descriptions(top[0].get('failed_conditions', [])) or 'no obvious blocker.'}")
        lines.append("Ask about a specific route for a deeper explanation.")
        title = "Current strategy ranking"

    return {
        "question": question,
        "title": title,
        "body": "\n".join(lines),
        "matches": top,
    }


def _fit_text(result: dict[str, Any], *, language: str = "zh") -> str:
    fit_level = result.get("fit_level")
    zh = {
        "strong": "适合",
        "conditional": "有条件适合",
        "weak": "偏弱",
        "poor": "不适合",
    }
    en = {
        "strong": "strong fit",
        "conditional": "conditional fit",
        "weak": "weak fit",
        "poor": "poor fit",
    }
    return (en if language == "en" else zh).get(fit_level, str(fit_level))


def _join_descriptions(items: list[dict[str, Any]]) -> str:
    return "；".join(str(item.get("description", "")) for item in items if item.get("description"))


def _format_checks(checks: list[str]) -> str:
    return "；".join(checks) if checks else "继续观察当前局势。"


def _collect_evidence(query_result: dict[str, Any]) -> list[dict[str, Any]]:
    if query_result.get("mode") == "single_flow_match":
        result = query_result.get("result", {})
        return [
            *result.get("matched_conditions", []),
            *result.get("failed_conditions", []),
        ]
    evidence: list[dict[str, Any]] = []
    for match in query_result.get("matches", [])[:3]:
        evidence.extend(match.get("matched_conditions", [])[:2])
        evidence.extend(match.get("failed_conditions", [])[:2])
    return evidence


def _state_summary(state: dict[str, Any]) -> dict[str, Any]:
    keys = [
        "turn",
        "era",
        "city_count",
        "science",
        "culture",
        "gold_per_turn",
        "faith_per_turn",
        "military_strength",
        "major_contacts",
        "minor_contacts",
        "at_war_count",
        "average_city_production",
    ]
    return {key: state.get(key) for key in keys if key in state}
