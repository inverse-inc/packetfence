"""OpenAI Chat Completions provider. Raw HTTP over the shared httpx client."""
from __future__ import annotations

import json

from .base import Provider, NeutralTool


class OpenAIProvider(Provider):
    default_model = "gpt-4o"
    endpoint = "https://api.openai.com/v1/chat/completions"

    def _tools_payload(self, tools: list[NeutralTool]) -> list[dict]:
        return [
            {
                "type": "function",
                "function": {
                    "name": t["name"],
                    "description": t["description"],
                    "parameters": t["parameters"],
                },
            }
            for t in tools
        ]

    def run_agent(self, system, history, tools, dispatch, label, max_iters=8):
        messages = [{"role": "system", "content": system}] + list(history)
        activity: list[str] = []
        headers = {"Authorization": f"Bearer {self.api_key}"}
        tools_payload = self._tools_payload(tools)
        total_input = 0
        total_output = 0

        for _ in range(max_iters):
            try:
                r = self.http.post(
                    self.endpoint,
                    headers=headers,
                    json={"model": self.model, "messages": messages, "tools": tools_payload},
                )
                data = r.json()
            except Exception as e:
                return (f"Could not reach OpenAI: {e}", activity, {"input_tokens": total_input, "output_tokens": total_output})

            u = data.get("usage") or {}
            total_input += u.get("prompt_tokens", 0)
            total_output += u.get("completion_tokens", 0)

            if "choices" not in data:
                return (data.get("error", {}).get("message", "Model error"), activity, {"input_tokens": total_input, "output_tokens": total_output})

            msg = data["choices"][0]["message"]
            messages.append(msg)

            if not msg.get("tool_calls"):
                return ((msg.get("content") or "").strip(), activity, {"input_tokens": total_input, "output_tokens": total_output})

            for tc in msg["tool_calls"]:
                name = tc["function"]["name"]
                try:
                    args = json.loads(tc["function"].get("arguments") or "{}")
                except Exception:
                    args = {}
                activity.append(label(name, args))
                messages.append(
                    {
                        "role": "tool",
                        "tool_call_id": tc["id"],
                        "content": json.dumps(dispatch(name, args))[:60000],
                    }
                )
        return ("(stopped after 8 steps)", activity, {"input_tokens": total_input, "output_tokens": total_output})

    def list_models(self):
        """Return chat-capable models available to this API key, newest first.
        Uses GET /v1/models. Filters to gpt-* and o-* families; marks a
        recommended default."""
        r = self.http.get(
            "https://api.openai.com/v1/models",
            headers={"Authorization": f"Bearer {self.api_key}"},
            timeout=15,
        )
        r.raise_for_status()
        data = r.json().get("data", [])
        models = []
        for m in data:
            mid = m.get("id", "")
            low = mid.lower()
            # keep chat/completion families; drop embeddings, audio, image, moderation
            if not (low.startswith("gpt") or low.startswith("o1") or low.startswith("o3")
                    or low.startswith("o4") or low.startswith("chatgpt")):
                continue
            if any(x in low for x in ("embedding", "whisper", "tts", "audio", "image",
                                      "dall-e", "moderation", "realtime", "transcribe",
                                      "search", "instruct")):
                continue
            models.append({"id": mid, "created": m.get("created", 0)})
        # newest first by created timestamp
        models.sort(key=lambda x: x["created"], reverse=True)
        recommended = {"gpt-4o", "gpt-4.1", "gpt-4o-mini"}
        return [{"id": m["id"], "recommended": m["id"] in recommended} for m in models]
