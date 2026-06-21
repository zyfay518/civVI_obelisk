from __future__ import annotations

import argparse
import json
from pathlib import Path

from .answer_builder import build_ai_context, build_player_answer
from .loader import load_knowledge_base
from .query_service import QueryService
from .state_mapper import map_obelisk_snapshot_to_state


def main() -> int:
    parser = argparse.ArgumentParser(description="Project Obelisk local knowledge matcher")
    parser.add_argument("--knowledge-root", default="knowledge")
    parser.add_argument("--state", required=True)
    parser.add_argument("--state-format", choices=["standard", "obelisk"], default="standard")
    parser.add_argument("--desired-victory", default="General")
    parser.add_argument("--question", default="我现在更适合小马流还是学院流？")
    parser.add_argument("--output", choices=["raw", "answer", "ai-context"], default="answer")
    args = parser.parse_args()

    kb = load_knowledge_base(args.knowledge_root)
    state = json.loads(Path(args.state).read_text(encoding="utf-8"))
    if args.state_format == "obelisk":
        state = map_obelisk_snapshot_to_state(state, desired_victory=args.desired_victory)
    service = QueryService(kb)
    result = service.answer(args.question, state)
    if args.output == "answer":
        result = build_player_answer(result)
    elif args.output == "ai-context":
        result = build_ai_context(result, state)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
