from __future__ import annotations

from typing import Any

from .schema import Condition


MISSING = object()


def get_state_value(state: dict[str, Any], dotted_key: str) -> Any:
    current: Any = state
    for part in dotted_key.split("."):
        if isinstance(current, dict) and part in current:
            current = current[part]
        else:
            return MISSING
    return current


def compare_values(actual: Any, operator: str, expected: Any) -> bool:
    if actual is MISSING:
        return False
    if operator == "==":
        return actual == expected
    if operator == "!=":
        return actual != expected
    if operator == ">":
        return actual > expected
    if operator == ">=":
        return actual >= expected
    if operator == "<":
        return actual < expected
    if operator == "<=":
        return actual <= expected
    if operator == "in":
        return actual in expected
    if operator == "not_in":
        return actual not in expected
    raise ValueError(f"Unsupported operator: {operator}")


def condition_matches(condition: Condition, state: dict[str, Any]) -> tuple[bool, Any]:
    actual = get_state_value(state, condition.state_key)
    return compare_values(actual, condition.operator, condition.value), actual
