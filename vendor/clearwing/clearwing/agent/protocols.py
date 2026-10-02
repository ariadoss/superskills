"""Protocol types for the agent runtime.

These structural (duck-typed) protocols replace the ``Any`` annotations that
previously appeared in :class:`NativeAgentGraph`, giving mypy something
concrete to check at the call-site without coupling the runtime to a
single concrete LLM implementation.
"""

from __future__ import annotations

from typing import Any, Protocol, runtime_checkable

from clearwing.llm.chat import AIMessage, BaseMessage


@runtime_checkable
class LLMInvokable(Protocol):
    """Anything that can be ``await``-ed with a list of messages."""

    async def ainvoke(self, messages: list[BaseMessage]) -> AIMessage: ...


class SystemPromptFactory(Protocol):
    """Callable that builds a system prompt from the current agent state."""

    def __call__(self, state: dict[str, Any]) -> str: ...


class StateUpdater(Protocol):
    """Callable that returns extra state keys after a tool runs."""

    def __call__(
        self, tool_name: str, data: Any, state: dict[str, Any]
    ) -> dict[str, Any]: ...


class KnowledgeGraphPopulator(Protocol):
    """Callable that feeds tool results into the knowledge graph."""

    def __call__(
        self, kg: Any, tool_name: str, content: str, state: dict[str, Any]
    ) -> dict[str, Any]: ...
