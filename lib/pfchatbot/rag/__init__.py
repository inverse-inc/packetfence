"""RAG components: fastembed-based embedder, in-memory vector index, corpus loader.

The index is rebuilt at process startup from a single PacketFence version's
OpenAPI spec, plus any local files and URLs configured via env vars.
"""
from __future__ import annotations

from .embedder import Embedder
from .index import Index, Document
from .corpus import load_openapi_operations, load_local_files, load_urls, chunk_text

__all__ = [
    "Embedder",
    "Index",
    "Document",
    "load_openapi_operations",
    "load_local_files",
    "load_urls",
    "chunk_text",
]
