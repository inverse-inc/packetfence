"""In-memory hybrid index: dense vectors (cosine) + BM25 keyword scoring,
merged with reciprocal rank fusion. The corpus is small enough (hundreds to a
few thousand chunks) that plain NumPy + a dict-based BM25 beat heavier deps.

Hybrid matters for ops documentation: embeddings capture paraphrase
("how do I wipe a device" ~ "delete node"), BM25 captures exact technical
tokens ("pfcmd", "RADIUS", "1812", config keys) that embeddings blur.
"""
from __future__ import annotations

import math
import re
from collections import Counter
from dataclasses import dataclass, field
from typing import Any, Optional

import numpy as np

_TOKEN_RE = re.compile(r"[a-z0-9][a-z0-9_.:\-/]*")

# RRF constant: standard value; lower gives more weight to top ranks.
_RRF_K = 60


def _tokenize(text: str) -> list[str]:
    return _TOKEN_RE.findall(text.lower())


@dataclass
class Document:
    text: str
    source_type: str  # "operation" | "file:<path>" | "url:<url>"
    meta: dict[str, Any] = field(default_factory=dict)


class _BM25:
    """Minimal Okapi BM25 over pre-tokenized docs."""

    K1 = 1.5
    B = 0.75

    def __init__(self, docs_tokens: list[list[str]]):
        self.n = len(docs_tokens)
        self.doc_len = [len(t) for t in docs_tokens]
        self.avg_len = (sum(self.doc_len) / self.n) if self.n else 0.0
        self.tf: list[Counter] = [Counter(t) for t in docs_tokens]
        df: Counter = Counter()
        for c in self.tf:
            df.update(c.keys())
        self.idf = {
            term: math.log(1 + (self.n - d + 0.5) / (d + 0.5)) for term, d in df.items()
        }

    def scores(self, query_tokens: list[str]) -> np.ndarray:
        out = np.zeros(self.n, dtype=np.float32)
        if not self.n or not self.avg_len:
            return out
        for term in query_tokens:
            idf = self.idf.get(term)
            if idf is None:
                continue
            for i, c in enumerate(self.tf):
                f = c.get(term)
                if not f:
                    continue
                denom = f + self.K1 * (1 - self.B + self.B * self.doc_len[i] / self.avg_len)
                out[i] += idf * f * (self.K1 + 1) / denom
        return out


class Index:
    def __init__(self):
        self.docs: list[Document] = []
        self.vectors: Optional[np.ndarray] = None  # (N, D) L2-normalized
        self._bm25: Optional[_BM25] = None

    def add(self, documents: list[Document], embedder, label: str = "") -> None:
        if not documents:
            return
        texts = [d.text for d in documents]
        vecs = embedder.embed(texts, kind="passage", label=label)
        if self.vectors is None:
            self.vectors = vecs
        else:
            self.vectors = np.vstack([self.vectors, vecs])
        self.docs.extend(documents)
        self._bm25 = None  # rebuilt lazily

    def _ensure_bm25(self) -> _BM25:
        if self._bm25 is None:
            self._bm25 = _BM25([_tokenize(d.text) for d in self.docs])
        return self._bm25

    def search(
        self,
        query: str,
        embedder,
        k: int = 8,
        source_types: Optional[list[str]] = None,
        reranker=None,
    ) -> list[dict]:
        """Top-k documents for `query` via hybrid retrieval:
        dense cosine ranking and BM25 keyword ranking fused with RRF,
        then (optionally) reordered by a cross-encoder reranker."""
        if self.vectors is None or self.vectors.size == 0:
            return []

        q = embedder.embed([query], kind="query")[0]
        dense = self.vectors @ q  # cosine (both sides L2-normalized)
        sparse = self._ensure_bm25().scores(_tokenize(query))

        # reciprocal rank fusion over the two rankings. Each list contributes
        # only for documents it actually ranks: BM25 excludes zero-score docs
        # (no query term matched), and both lists are capped to a window so a
        # long tail of near-ties can't drown out strong signals.
        window = max(k * 10, 100)
        fused = np.zeros(len(self.docs), dtype=np.float32)
        for scores, require_positive in ((dense, False), (sparse, True)):
            order = np.argsort(-scores)[:window]
            for rank, idx in enumerate(order):
                if require_positive and scores[idx] <= 0:
                    break  # sorted desc: everything after is also <= 0
                fused[idx] += 1.0 / (_RRF_K + rank + 1)

        order = np.argsort(-fused)
        # gather a candidate pool (larger than k when reranking)
        pool_size = max(k * 3, 20) if reranker else k
        candidates: list[int] = []
        for idx in order:
            if len(candidates) >= pool_size:
                break
            doc = self.docs[int(idx)]
            if source_types and not _source_matches(doc.source_type, source_types):
                continue
            candidates.append(int(idx))

        if reranker and len(candidates) > 1:
            try:
                rr = reranker.rerank(query, [self.docs[i].text for i in candidates])
                candidates = [candidates[i] for i in np.argsort(-np.asarray(rr))]
            except Exception as e:
                print(f"[rag] rerank failed (falling back to fusion order): {e}")
        candidates = candidates[:k]

        return [
            {
                "text": self.docs[i].text,
                "source_type": self.docs[i].source_type,
                "meta": self.docs[i].meta,
                "score": float(fused[i]),
            }
            for i in candidates
        ]

    def __len__(self) -> int:
        return len(self.docs)


def _source_matches(source_type: str, allowed: list[str]) -> bool:
    for a in allowed:
        if a.endswith(":") and source_type.startswith(a):
            return True
        if source_type == a:
            return True
    return False
