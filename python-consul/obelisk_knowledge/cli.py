from __future__ import annotations

import argparse
import json
from pathlib import Path

from .loader import load_knowledge_base
from .query_service import QueryService


def main() -> int:
    parser = argparse.ArgumentParser(description="Project Obelisk local knowledge matcher")
    parser.add_argument("--knowledge-root", default="knowledge")
    parser.add_argument("--state", required=True)
    parser.add_argument("--question", default="我现在更适合小马流还是学院流？")
    args = parser.parse_args()

    kb = load_knowledge_base(args.knowledge_root)
    state = json.loads(Path(args.state).read_text(encoding="utf-8"))
    service = QueryService(kb)
    print(json.dumps(service.answer(args.question, state), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
