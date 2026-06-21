"""Local knowledge base matching for Project Obelisk."""

from .loader import KnowledgeBase, load_knowledge_base
from .query_service import QueryService
from .schema import MatchResult, MetaFlow, RuleEntry
from .state_mapper import map_obelisk_snapshot_to_state

__all__ = [
    "KnowledgeBase",
    "MatchResult",
    "MetaFlow",
    "QueryService",
    "RuleEntry",
    "load_knowledge_base",
    "map_obelisk_snapshot_to_state",
]
