"""Abstract provider interface. See providers/openai.py, providers/anthropic.py."""
from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Callable


# Neutral tool schema, shared across providers:
#   [{"name": str, "description": str, "parameters": <JSON Schema>}]
# Each provider converts to its wire format internally.
NeutralTool = dict


class Provider(ABC):
    default_model: str = ""

    def __init__(self, api_key: str, model: str, http):
        self.api_key = api_key
        self.model = model
        self.http = http

    @abstractmethod
    def run_agent(
        self,
        system: str,
        history: list[dict],
        tools: list[NeutralTool],
        dispatch: Callable[[str, dict], dict],
        label: Callable[[str, dict], str],
        max_iters: int = 8,
    ) -> tuple[str, list[str]]:
        """Run a tool-calling loop until the model produces a final answer.

        Args:
            system: System prompt.
            history: Chat turns from the browser as [{role, content: str}].
            tools: Neutral tool schemas.
            dispatch: Executes a tool call by (name, args) → result dict.
            label: Human-readable activity label for (name, args).
            max_iters: Cap on model→tool round trips.

        Returns:
            (final_reply_text, activity_labels)
        """
