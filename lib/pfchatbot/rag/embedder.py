"""fastembed wrappers. ONNX-based, CPU-only, no torch dependency.

The embedding model is downloaded to ~/.cache/fastembed on first init (~30MB
for BAAI/bge-small-en-v1.5). Override via RAG_EMBED_MODEL.

BGE-family models are trained with asymmetric prefixes: queries and passages
are embedded differently. fastembed exposes query_embed()/passage_embed()
which apply the right prefixes; using them measurably improves retrieval over
plain embed(). We use them when available and fall back gracefully otherwise.
"""
from __future__ import annotations

import os
import time

import numpy as np


DEFAULT_MODEL = "BAAI/bge-small-en-v1.5"


class Embedder:
    def __init__(self, model_name: str = DEFAULT_MODEL, batch_size: int = 32):
        import os
        # Keep ONNX from grabbing every core on a shared host (PacketFence needs
        # CPU too). Set before importing fastembed so the runtime picks it up.
        n = os.environ.get("RAG_EMBED_THREADS", "2")
        os.environ.setdefault("OMP_NUM_THREADS", n)
        os.environ.setdefault("ORT_NUM_THREADS", n)
        from fastembed import TextEmbedding  # lazy: heavy import at first use

        self.model_name = model_name
        try:
            self._model = TextEmbedding(model_name=model_name,
                                        threads=int(n) if n.isdigit() else None)
        except TypeError:
            self._model = TextEmbedding(model_name=model_name)
        # Cap how many texts are embedded per pass. Keeps peak memory flat on
        # large corpora — embedding everything in one list() call can spike RAM
        # enough to trip the OOM killer on memory-tight hosts (e.g. PacketFence).
        try:
            self.batch_size = max(1, int(os.environ.get("RAG_EMBED_BATCH", batch_size)))
        except ValueError:
            self.batch_size = batch_size

    def embed(self, texts: list[str], kind: str = "passage", label: str = "") -> np.ndarray:
        """(N, D) float32 L2-normalized embeddings, computed in bounded batches.
        kind: "passage" for corpus documents, "query" for search queries.

        Prints progress for large corpora — a first-boot re-index takes minutes
        on a memory-tight host, and silence is indistinguishable from a hang."""
        if not texts:
            return np.zeros((0, 0), dtype=np.float32)
        fn = getattr(
            self._model, "query_embed" if kind == "query" else "passage_embed", None
        )
        out: list[np.ndarray] = []
        bs = self.batch_size
        total = len(texts)
        chatty = kind == "passage" and total >= 200
        t0 = time.time()
        next_pct = 10
        if chatty:
            print(f"[rag] embedding {total} {label or 'chunks'} "
                  f"(batch={bs}, threads={os.environ.get('OMP_NUM_THREADS','?')})…",
                  flush=True)
        for i in range(0, len(texts), bs):
            batch = texts[i:i + bs]
            try:
                vecs = np.array(list(fn(batch)), dtype=np.float32) if fn else None
            except Exception:
                vecs = None
            if vecs is None or vecs.ndim != 2 or vecs.shape[0] != len(batch):
                vecs = np.array(list(self._model.embed(batch)), dtype=np.float32)
            out.append(vecs)
            if chatty:
                done = min(i + bs, total)
                pct = done * 100 // total
                if pct >= next_pct or done == total:
                    el = time.time() - t0
                    rate = done / el if el > 0 else 0
                    eta = (total - done) / rate if rate > 0 else 0
                    print(f"[rag]   {done}/{total} ({pct}%) "
                          f"{rate:.0f}/s, ~{eta:.0f}s left", flush=True)
                    next_pct = pct + 10
        vecs = np.vstack(out) if out else np.zeros((0, 0), dtype=np.float32)
        norms = np.linalg.norm(vecs, axis=1, keepdims=True)
        norms[norms == 0] = 1.0
        return vecs / norms


class Reranker:
    """Optional cross-encoder reranker (opt-in via RAG_RERANK_MODEL).
    Scores (query, passage) pairs jointly — slower per query than embedding
    search, but markedly more accurate ordering of the candidate pool.
    A good default model id: 'Xenova/ms-marco-MiniLM-L-6-v2' (~90MB)."""

    def __init__(self, model_name: str):
        from fastembed.rerank.cross_encoder import TextCrossEncoder  # lazy

        self.model_name = model_name
        self._model = TextCrossEncoder(model_name=model_name)

    def rerank(self, query: str, passages: list[str]) -> list[float]:
        return [float(s) for s in self._model.rerank(query, passages)]
