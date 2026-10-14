"""Load documents into the RAG index from three sources:

  1. OpenAPI operations (parsed from the loaded spec)
  2. Local files on the host (text formats read directly; PDFs via pypdf)
  3. URLs fetched at startup

Chunking is paragraph-aware: paragraphs are packed into ~CHUNK_SIZE windows
without splitting sentences, with a sentence-boundary overlap between chunks.
PDF chunks carry a page number in meta so answers can cite pages.
"""
from __future__ import annotations

import os
import re
from typing import Any

from .index import Document

# Bump when chunking logic changes so cached embeddings are invalidated.
CORPUS_VERSION = "2"

CHUNK_SIZE = 1000
CHUNK_OVERLAP = 200

_PARA_RE = re.compile(r"\n\s*\n")
_SENT_RE = re.compile(r"(?<=[.!?])\s+(?=[A-Z0-9])")


def _split_sentences(text: str) -> list[str]:
    parts = _SENT_RE.split(text)
    return [p for p in parts if p.strip()]


def _tail(text: str, overlap: int) -> str:
    """Last <= overlap chars of text, cut at a sentence boundary when possible."""
    if len(text) <= overlap:
        return text
    tail = text[-overlap:]
    sents = _split_sentences(tail)
    if len(sents) > 1:
        return " ".join(sents[1:])
    return tail


def chunk_text(text: str, size: int = CHUNK_SIZE, overlap: int = CHUNK_OVERLAP) -> list[str]:
    """Pack paragraphs into chunks of ~`size` chars without splitting sentences.
    Consecutive chunks share a sentence-boundary overlap of ~`overlap` chars.
    Oversized paragraphs are split on sentence boundaries first."""
    if not text:
        return []

    # normalize into units no longer than `size`
    units: list[str] = []
    for para in _PARA_RE.split(text):
        para = para.strip()
        if not para:
            continue
        if len(para) <= size:
            units.append(para)
            continue
        cur = ""
        for sent in _split_sentences(para) or [para]:
            if len(sent) > size:  # pathological run-on: hard-split
                if cur:
                    units.append(cur)
                    cur = ""
                units.extend(sent[i : i + size] for i in range(0, len(sent), size))
            elif len(cur) + len(sent) + 1 <= size:
                cur = (cur + " " + sent).strip()
            else:
                units.append(cur)
                cur = sent
        if cur:
            units.append(cur)

    chunks: list[str] = []
    cur = ""
    for u in units:
        if not cur:
            cur = u
        elif len(cur) + len(u) + 2 <= size:
            cur = cur + "\n\n" + u
        else:
            chunks.append(cur)
            carry = _tail(cur, overlap)
            cur = (carry + "\n\n" + u) if carry and len(carry) + len(u) + 2 <= size else u
    if cur:
        chunks.append(cur)
    return [c for c in chunks if c.strip()]


_TAG_RE = re.compile(r"<[^>]+>")
_SCRIPT_STYLE_RE = re.compile(r"<(script|style)[^>]*>.*?</\1>", flags=re.S | re.I)
_WS_RE = re.compile(r"[ \t]+")


def _strip_html(html: str) -> str:
    html = _SCRIPT_STYLE_RE.sub(" ", html)
    # preserve block boundaries as paragraph breaks so chunking stays structural
    html = re.sub(r"</(p|div|li|h[1-6]|tr|section|article)>", "\n\n", html, flags=re.I)
    text = _TAG_RE.sub(" ", html)
    text = _WS_RE.sub(" ", text)
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def load_openapi_operations(ops: dict[str, dict]) -> list[Document]:
    """Turn each OpenAPI operation (already parsed by app.load_spec) into one
    Document, so semantic search over ops works.

    Deliberately kept short: the lexical half of the search (app.search_ops)
    tokenises ids and paths at QUERY time, so the resource noun is reachable
    without re-embedding the whole corpus."""
    documents: list[Document] = []
    for oid, o in ops.items():
        text = " ".join(
            filter(
                None,
                [
                    oid,
                    o["method"].upper(),
                    o["path"],
                    o.get("summary", ""),
                    o.get("description", ""),
                    " ".join(o.get("tags", []) or []),
                ],
            )
        )
        documents.append(
            Document(
                text=text,
                source_type="operation",
                meta={
                    "operation_id": oid,
                    "method": o["method"].upper(),
                    "path": o["path"],
                    "summary": o.get("summary", ""),
                    "is_write": o.get("is_write", False),
                },
            )
        )
    return documents


_ADOC_INCLUDE = re.compile(r"^\s*include::([^\[\]]+)\[[^\]]*\]\s*$", re.M)
# hard ceiling on resolved AsciiDoc text per master file (bytes). A pathological
# include tree can otherwise balloon far beyond the on-disk size and OOM.
_ADOC_MAX_BYTES = 4 * 1024 * 1024   # 4 MB of resolved text per guide is plenty


def _read_asciidoc(path: str, _seen: set | None = None, _depth: int = 0,
                   _budget: list | None = None) -> str:
    """Read an AsciiDoc file, recursively inline any include:: directives it
    references, then strip AsciiDoc markup down to clean plain text.

    Guards against runaway expansion: dedups already-seen files (_seen), caps
    recursion depth, and enforces a total resolved-byte budget (_budget) shared
    across the whole tree so a fan-out of includes can't exhaust memory."""
    _seen = _seen if _seen is not None else set()
    _budget = _budget if _budget is not None else [_ADOC_MAX_BYTES]
    real = os.path.realpath(path)
    if real in _seen or _depth > 25 or _budget[0] <= 0:
        return ""
    _seen.add(real)
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            raw = f.read()
    except OSError as e:
        print(f"[rag] could not read asciidoc {path}: {e}")
        return ""

    base = os.path.dirname(path)

    def _inline(m):
        if _budget[0] <= 0:
            return ""
        target = m.group(1).strip()
        target = target.replace("{src_path}", ".").replace("{docdir}", base)
        inc_path = target if os.path.isabs(target) else os.path.join(base, target)
        if os.path.isfile(inc_path):
            return _read_asciidoc(inc_path, _seen, _depth + 1, _budget)
        return ""

    text = _ADOC_INCLUDE.sub(_inline, raw)
    _budget[0] -= len(text)
    if _budget[0] <= 0:
        print(f"[rag] asciidoc resolved-size budget hit at {path}; truncating")
    return _strip_asciidoc(text)


def _strip_asciidoc(text: str) -> str:
    """Reduce AsciiDoc markup to readable plain text. Not a full renderer — just
    enough that embeddings see prose, not syntax noise."""
    out_lines: list[str] = []
    in_block = False
    for ln in text.splitlines():
        s = ln.rstrip()
        # skip delimited blocks' fences but keep their content
        if re.match(r"^(----|====|\*\*\*\*|\.\.\.\.|\|===|\+\+\+\+|////)\s*$", s):
            in_block = not in_block if s.startswith("////") else in_block
            continue
        if s.startswith("////"):           # comment block toggle
            in_block = not in_block
            continue
        if in_block:                        # inside a comment block: skip
            continue
        # drop attribute entries, block attributes, and IDs
        if re.match(r"^:[\w!-]+:.*$", s):   # :attribute: value
            continue
        if re.match(r"^\[.*\]$", s):        # [source,bash] / [NOTE] / [#id]
            continue
        if re.match(r"^(ifdef|ifndef|endif|ifeval)::", s):
            continue
        if s.startswith("//"):              # line comment
            continue
        # headings: strip leading = markers, keep the title text
        s = re.sub(r"^=+\s+", "", s)
        # list markers -> keep text
        s = re.sub(r"^\s*[\*\-\.]+\s+", "", s)
        # inline markup: links, xrefs, formatting, images
        s = re.sub(r"link:(\S+)\[([^\]]*)\]", lambda m: m.group(2) or m.group(1), s)
        s = re.sub(r"xref:[^\[]+\[([^\]]*)\]", r"\1", s)
        s = re.sub(r"image::?[^\[]+\[[^\]]*\]", "", s)
        s = re.sub(r"`([^`]+)`", r"\1", s)          # monospace
        s = re.sub(r"\*([^*]+)\*", r"\1", s)        # bold
        s = re.sub(r"_([^_]+)_", r"\1", s)          # italic
        s = re.sub(r"\{[\w!-]+\}", "", s)           # unresolved attributes
        out_lines.append(s)
    # collapse runs of blank lines
    cleaned = re.sub(r"\n{3,}", "\n\n", "\n".join(out_lines))
    return cleaned.strip()


def _read_pdf_pages(path: str) -> list[tuple[int, str]]:
    """(page_number, text) per page. Empty list if no extractable text."""
    from pypdf import PdfReader  # lazy import; only needed when PDFs are configured

    reader = PdfReader(path)
    pages = []
    for i, page in enumerate(reader.pages, start=1):
        t = page.extract_text() or ""
        if t.strip():
            pages.append((i, t))
    return pages


def load_local_files(paths: list[str]) -> list[Document]:
    documents: list[Document] = []
    # Expand any directory entries into the doc files they contain, so callers
    # can point RAG_LOCAL_FILES at a folder (e.g. /docs) instead of listing every
    # file. Recurses one level; indexes common text/PDF doc formats only.
    _DOC_EXTS = (".txt", ".md", ".pdf", ".html", ".htm", ".rst", ".asciidoc", ".adoc")
    expanded: list[str] = []
    for path in paths:
        path = path.strip()
        if not path:
            continue
        if os.path.isdir(path):
            found = 0
            adoc_masters = []
            other_docs = []
            for root, _dirs, files in os.walk(path):
                for fn in sorted(files):
                    if fn.startswith("."):
                        continue
                    low = fn.lower()
                    full = os.path.join(root, fn)
                    if low.endswith(".asciidoc"):
                        # top-level guide files (PacketFence_*_Guide.asciidoc) that
                        # include:: their fragments; index these, not the fragments
                        adoc_masters.append(full)
                    elif low.endswith(".adoc"):
                        # fragment/included file — skip in directory mode to avoid
                        # double-indexing (its content is pulled in via a master)
                        continue
                    elif low.endswith(_DOC_EXTS):
                        other_docs.append(full)
            for f in adoc_masters + other_docs:
                expanded.append(f); found += 1
            if found == 0:
                print(f"[rag] no indexable docs found in directory: {path}")
        else:
            expanded.append(path)

    for path in expanded:
        path = path.strip()
        if not path:
            continue
        if not os.path.isfile(path):
            print(f"[rag] local file not found, skipping: {path}")
            continue
        try:
            if path.lower().endswith(".pdf"):
                pages = _read_pdf_pages(path)
                if not pages:
                    print(f"[rag] no extractable text in PDF (scanned?), skipping: {path}")
                    continue
                for pageno, text in pages:
                    for chunk in chunk_text(text):
                        documents.append(
                            Document(
                                text=chunk,
                                source_type=f"file:{path}",
                                meta={"path": path, "page": pageno},
                            )
                        )
                continue
            if path.lower().endswith((".asciidoc", ".adoc")):
                content = _read_asciidoc(path)
                if not content.strip():
                    print(f"[rag] asciidoc produced no text, skipping: {path}")
                    continue
            else:
                with open(path, "r", encoding="utf-8", errors="replace") as f:
                    content = f.read()
        except Exception as e:
            print(f"[rag] could not read {path}: {e}")
            continue
        for chunk in chunk_text(content):
            documents.append(
                Document(text=chunk, source_type=f"file:{path}", meta={"path": path})
            )
    return documents


def load_urls(urls: list[str], http) -> list[Document]:
    documents: list[Document] = []
    for url in urls:
        url = url.strip()
        if not url:
            continue
        try:
            r = http.get(url)
            r.raise_for_status()
        except Exception as e:
            print(f"[rag] could not fetch {url}: {e}")
            continue
        ctype = (r.headers.get("content-type") or "").lower()
        body = r.text
        text = _strip_html(body) if "html" in ctype else body
        for chunk in chunk_text(text):
            documents.append(
                Document(text=chunk, source_type=f"url:{url}", meta={"url": url})
            )
    return documents
