"""Convert the HTML guides rendered at image build time to plain text for the
RAG corpus, with the same rules fetch_docs.sh uses.

    python3 docs_to_text.py <html dir> <output dir>
"""
import pathlib
import re
import sys


def html_to_text(html: str) -> str:
    html = re.sub(r"<(script|style)\b.*?</\1>", " ", html, flags=re.I | re.S)
    html = re.sub(r"</(p|div|li|h[1-6]|tr|section|article)>", "\n\n", html, flags=re.I)
    text = re.sub(r"<[^>]+>", " ", html)
    for a, b in [("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
                 ("&quot;", '"'), ("&#39;", "'")]:
        text = text.replace(a, b)
    text = re.sub(r"[ \t]+", " ", text)
    return re.sub(r"\n{3,}", "\n\n", text)


def main() -> int:
    src, dst = (pathlib.Path(p) for p in sys.argv[1:3])
    dst.mkdir(parents=True, exist_ok=True)
    guides = sorted(src.glob("*.html"))
    if not guides:
        print(f"no .html guides in {src}", file=sys.stderr)
        return 1
    for f in guides:
        out = dst / (f.stem + ".txt")
        out.write_text(html_to_text(f.read_text(encoding="utf-8", errors="replace")), encoding="utf-8")
        print(f"  {out.name}: {out.stat().st_size} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
