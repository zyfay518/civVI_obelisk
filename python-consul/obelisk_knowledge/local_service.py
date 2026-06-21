from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

from .answer_builder import build_ai_context, build_player_answer
from .loader import load_knowledge_base
from .query_service import QueryService
from .state_mapper import map_obelisk_snapshot_to_state


class ConsulApplication:
    def __init__(self, knowledge_root: str):
        self.knowledge_root = knowledge_root
        self.service = QueryService(load_knowledge_base(knowledge_root))

    def answer(self, payload: dict[str, Any]) -> dict[str, Any]:
        question = str(payload.get("question", "我现在更适合哪个流派？"))
        state = payload.get("state", {})
        state_format = payload.get("state_format", "standard")
        desired_victory = str(payload.get("desired_victory", "General"))
        output = payload.get("output", "answer")

        if not isinstance(state, dict):
            raise ValueError("state must be a JSON object")

        if state_format == "obelisk":
            state = map_obelisk_snapshot_to_state(state, desired_victory=desired_victory)
        elif state_format != "standard":
            raise ValueError("state_format must be 'standard' or 'obelisk'")

        result = self.service.answer(question, state)
        if output == "raw":
            return result
        if output == "ai-context":
            return build_ai_context(result, state)
        if output == "answer":
            return build_player_answer(result)
        raise ValueError("output must be 'answer', 'raw', or 'ai-context'")


def make_handler(app: ConsulApplication) -> type[BaseHTTPRequestHandler]:
    class Handler(BaseHTTPRequestHandler):
        server_version = "ObeliskConsul/0.1"

        def do_GET(self) -> None:
            if self.path == "/health":
                self._send_json({"ok": True, "knowledge_root": app.knowledge_root})
                return
            self._send_json({"error": "not_found"}, status=404)

        def do_POST(self) -> None:
            if self.path != "/answer":
                self._send_json({"error": "not_found"}, status=404)
                return

            try:
                length = int(self.headers.get("Content-Length", "0"))
                raw = self.rfile.read(length).decode("utf-8")
                payload = json.loads(raw or "{}")
                response = app.answer(payload)
                self._send_json(response)
            except Exception as exc:  # noqa: BLE001 - service boundary returns structured errors.
                self._send_json({"error": str(exc)}, status=400)

        def log_message(self, format: str, *args: Any) -> None:
            return

        def _send_json(self, payload: dict[str, Any], *, status: int = 200) -> None:
            body = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    return Handler


def main() -> int:
    parser = argparse.ArgumentParser(description="Project Obelisk local Consul service")
    parser.add_argument("--knowledge-root", default="knowledge")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()

    app = ConsulApplication(args.knowledge_root)
    server = ThreadingHTTPServer((args.host, args.port), make_handler(app))
    print(f"Obelisk Consul listening on http://{args.host}:{args.port}")
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
