"""
Provider abstraction: pick an LLM backend by PROVIDER env var and expose a
uniform run_agent(...) surface. Callers stay provider-agnostic.
"""
from __future__ import annotations

from .base import Provider
from .openai import OpenAIProvider
from .anthropic import AnthropicProvider

_REGISTRY = {
    "openai": OpenAIProvider,
    "anthropic": AnthropicProvider,
}


def build(provider_name: str, api_key: str, model: str | None, http):
    key = (provider_name or "").strip().lower()
    if key not in _REGISTRY:
        raise ValueError(
            f"Unknown PROVIDER {provider_name!r}. Supported: {', '.join(_REGISTRY)}."
        )
    cls = _REGISTRY[key]
    return cls(api_key=api_key, model=model or cls.default_model, http=http)


__all__ = ["Provider", "OpenAIProvider", "AnthropicProvider", "build"]
