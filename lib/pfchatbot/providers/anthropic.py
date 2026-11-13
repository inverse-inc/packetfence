"""Anthropic Messages API provider. Raw HTTP over the shared httpx client."""
from __future__ import annotations

import json

from .base import Provider, NeutralTool


class AnthropicProvider(Provider):
    default_model = "claude-opus-4-8"
    endpoint = "https://api.anthropic.com/v1/messages"
    api_version = "2023-06-01"
    max_response_tokens = 4096

    def _tools_payload(self, tools: list[NeutralTool]) -> list[dict]:
        return [
            {"name": t["name"], "description": t["description"], "input_schema": t["parameters"]}
            for t in tools
        ]

    def _normalize_history(self, history: list[dict]) -> list[dict]:
        # Browser sends [{role, content: str}]. Anthropic requires the first message
        # to be role=user; if the client somehow leads with assistant, drop it.
        out = []
        for m in history:
            role = m.get("role")
            if role in ("user", "assistant"):
                out.append({"role": role, "content": m.get("content", "")})
        while out and out[0]["role"] != "user":
            out.pop(0)
        return out

    def run_agent(self, system, history, tools, dispatch, label, max_iters=8):
        messages = self._normalize_history(history)
        activity: list[str] = []
        headers = {
            "x-api-key": self.api_key,
            "anthropic-version": self.api_version,
            "content-type": "application/json",
        }
        tools_payload = self._tools_payload(tools)
        total_input = 0
        total_output = 0

        for _ in range(max_iters):
            try:
                r = self.http.post(
                    self.endpoint,
                    headers=headers,
                    json={
                        "model": self.model,
                        "max_tokens": self.max_response_tokens,
                        "system": system,
                        "messages": messages,
                        "tools": tools_payload,
                    },
                )
                data = r.json()
            except Exception as e:
                return (f"Could not reach Anthropic: {e}", activity, {"input_tokens": total_input, "output_tokens": total_output})

            u = data.get("usage") or {}
            total_input += u.get("input_tokens", 0)
            total_output += u.get("output_tokens", 0)

            if "content" not in data:
                err = data.get("error", {})
                return (err.get("message") or "Model error", activity, {"input_tokens": total_input, "output_tokens": total_output})

            content = data["content"]
            stop = data.get("stop_reason")
            tool_uses = [b for b in content if b.get("type") == "tool_use"]

            if stop == "tool_use" and tool_uses:
                # Echo the full assistant content back (text + tool_use + any thinking
                # blocks) so subsequent turns preserve the model's own record.
                messages.append({"role": "assistant", "content": content})
                results = []
                for tu in tool_uses:
                    name = tu["name"]
                    args = tu.get("input") or {}
                    activity.append(label(name, args))
                    results.append(
                        {
                            "type": "tool_result",
                            "tool_use_id": tu["id"],
                            "content": json.dumps(dispatch(name, args))[:60000],
                        }
                    )
                messages.append({"role": "user", "content": results})
                continue

            text = "".join(b.get("text", "") for b in content if b.get("type") == "text")
            return (text.strip(), activity, {"input_tokens": total_input, "output_tokens": total_output})

        return ("(stopped after 8 steps)", activity, {"input_tokens": total_input, "output_tokens": total_output})

    def list_models(self):
        """Return Claude models available to this API key, newest first.
        Uses GET /v1/models."""
        r = self.http.get(
            "https://api.anthropic.com/v1/models",
            headers={
                "x-api-key": self.api_key,
                "anthropic-version": self.api_version,
            },
            params={"limit": 100},
            timeout=15,
        )
        r.raise_for_status()
        data = r.json().get("data", [])
        models = []
        for m in data:
            mid = m.get("id", "")
            models.append({"id": mid, "created": m.get("created_at", "")})
        # the API returns newest first already; keep that order
        recommended_substr = ("sonnet", "opus")
        out = []
        for m in models:
            low = m["id"].lower()
            out.append({"id": m["id"],
                        "recommended": any(s in low for s in recommended_substr) and "latest" not in low})
        return out
