from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .schema import MetaFlow, RuleEntry


@dataclass(frozen=True)
class KnowledgeBase:
    root: Path
    rules: list[RuleEntry]
    metas: list[MetaFlow]

    def get_meta(self, meta_id_or_name: str) -> MetaFlow | None:
        normalized = meta_id_or_name.strip().lower()
        for meta in self.metas:
            if meta.id.lower() == normalized or meta.name.lower() == normalized:
                return meta
        return None


def _read_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _iter_json_files(path: Path) -> list[Path]:
    if not path.exists():
        return []
    return sorted(item for item in path.rglob("*.json") if item.is_file())


def _load_rules(root: Path) -> list[RuleEntry]:
    rules: list[RuleEntry] = []
    for path in _iter_json_files(root / "published" / "rules"):
        payload = _read_json(path)
        entries = payload if isinstance(payload, list) else [payload]
        for entry in entries:
            rules.append(RuleEntry.from_dict(entry))
    return rules


def _load_metas(root: Path) -> list[MetaFlow]:
    metas: list[MetaFlow] = []
    for path in _iter_json_files(root / "metas"):
        payload = _read_json(path)
        entries = payload if isinstance(payload, list) else [payload]
        for entry in entries:
            metas.append(MetaFlow.from_dict(entry))
    return metas


def load_knowledge_base(root: str | Path) -> KnowledgeBase:
    knowledge_root = Path(root)
    return KnowledgeBase(
        root=knowledge_root,
        rules=_load_rules(knowledge_root),
        metas=_load_metas(knowledge_root),
    )
