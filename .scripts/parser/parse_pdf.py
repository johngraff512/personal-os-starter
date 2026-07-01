"""
Vision-LLM PDF parser for brainiac.

Two parse modes:
  - "full"    : extracts the entire document. HTML tables for merged cells,
                charts converted to flat-header data tables, bracketed image
                descriptions. Best for unique documents (your own materials,
                course notes, internal docs).
  - "summary" : detailed reference summary with APA citation, section summaries,
                tables described with key data extracted, short attributed
                quotes only. For academic fair-use citation. Used as automatic
                fallback when full extraction is blocked by Anthropic's content
                filter (typical for known published articles), or via --summary.

Run as a module:
    python -m parser.parse_pdf <pdf>                    # tries full, falls back to summary
    python -m parser.parse_pdf <pdf> --summary          # forces summary mode
    python -m parser.parse_pdf <pdf> --out result.md
    python -m parser.parse_pdf <pdf> --model claude-sonnet-4-6

Or import:
    from parser.parse_pdf import parse_pdf, ParseResult
    result = parse_pdf(Path("doc.pdf"))
    print(result.mode, result.markdown)
"""

from __future__ import annotations

import argparse
import base64
import dataclasses
import os
import subprocess
import sys
from io import BytesIO
from pathlib import Path

from .prompts import (
    SYSTEM_PROMPT,
    USER_PROMPT,
    SUMMARY_SYSTEM_PROMPT,
    SUMMARY_USER_PROMPT,
)

DEFAULT_MODEL = "claude-haiku-4-5-20251001"
COST_CEILING_PAGES = 50
MAX_OUTPUT_TOKENS = 16000

SUMMARY_NOTE_PREFIX = (
    "> **Note — detailed reference summary, not verbatim extraction.** "
    "Full extraction of this document was blocked by Anthropic's content filter "
    "(typical for known published works). This is a structured summary for academic "
    "fair-use citation. The original PDF is retained at the source path; consult it "
    "for any verbatim quotation beyond the load-bearing short quotes included below.\n\n"
)


@dataclasses.dataclass
class ParseResult:
    markdown: str
    model: str
    input_tokens: int
    output_tokens: int
    pages: int
    mode: str  # "full" or "summary"


def _api_key() -> str:
    env_key = os.environ.get("ANTHROPIC_API_KEY")
    if env_key:
        return env_key
    try:
        return subprocess.check_output(
            ["security", "find-generic-password", "-s", "<your-keychain-entry>", "-w"],
            text=True,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        raise RuntimeError(
            "No API key. Set ANTHROPIC_API_KEY or store it in macOS Keychain:\n"
            '  security add-generic-password -s "<your-keychain-entry>" -a "$USER" -w "<key>"'
        ) from e


def _count_pages(pdf_bytes: bytes) -> int:
    try:
        from pypdf import PdfReader
    except ImportError as e:
        raise RuntimeError("pypdf not installed. Run: pip install pypdf") from e
    return len(PdfReader(BytesIO(pdf_bytes)).pages)


def _confirm_large(pdf_path: Path, pages: int) -> bool:
    if os.environ.get("BRAINIAC_PARSER_FORCE") == "1":
        return True
    if not sys.stdin.isatty():
        print(
            f"[parser] {pdf_path.name} has {pages} pages (> {COST_CEILING_PAGES}). "
            f"Skipping in non-interactive run. Set BRAINIAC_PARSER_FORCE=1 to override.",
            file=sys.stderr,
        )
        return False
    answer = input(
        f"[parser] {pdf_path.name} has {pages} pages (> {COST_CEILING_PAGES}). Parse anyway? [y/N] "
    ).strip().lower()
    return answer in ("y", "yes")


def _is_content_filter_block(exc: Exception) -> bool:
    msg = str(exc).lower()
    return any(needle in msg for needle in (
        "content filtering",
        "content filter",
        "output blocked",
    ))


def _strip_code_fence(text: str) -> str:
    text = text.strip()
    if not text.startswith("```"):
        return text
    lines = text.splitlines()
    if lines[0].startswith("```"):
        lines = lines[1:]
    if lines and lines[-1].strip() == "```":
        lines = lines[:-1]
    return "\n".join(lines).strip()


def _call_anthropic(client, pdf_bytes, model, pages, system_prompt, user_prompt, mode):
    msg = client.messages.create(
        model=model,
        max_tokens=MAX_OUTPUT_TOKENS,
        system=system_prompt,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "document",
                        "source": {
                            "type": "base64",
                            "media_type": "application/pdf",
                            "data": base64.standard_b64encode(pdf_bytes).decode(),
                        },
                    },
                    {"type": "text", "text": user_prompt},
                ],
            }
        ],
    )

    parts = [block.text for block in msg.content if getattr(block, "type", None) == "text"]
    markdown = _strip_code_fence("\n".join(parts))

    if mode == "summary":
        markdown = SUMMARY_NOTE_PREFIX + markdown

    return ParseResult(
        markdown=markdown,
        model=msg.model,
        input_tokens=msg.usage.input_tokens,
        output_tokens=msg.usage.output_tokens,
        pages=pages,
        mode=mode,
    )


def parse_pdf(
    pdf_path: Path,
    model: str = DEFAULT_MODEL,
    force_summary: bool = False,
) -> ParseResult:
    """
    Parse a PDF via Claude vision.

    Returns a ParseResult with `.mode` set to "full" or "summary".
    By default, attempts full extraction first; on content-filter block,
    automatically retries with summary mode for fair-use academic reference.
    """
    try:
        from anthropic import Anthropic
        import anthropic as anthropic_pkg
    except ImportError as e:
        raise RuntimeError("anthropic not installed. Run: pip install anthropic") from e

    pdf_bytes = pdf_path.read_bytes()
    pages = _count_pages(pdf_bytes)
    if pages > COST_CEILING_PAGES and not _confirm_large(pdf_path, pages):
        raise RuntimeError(f"aborted by cost guard ({pages} pages > {COST_CEILING_PAGES})")

    client = Anthropic(api_key=_api_key())

    if force_summary:
        return _call_anthropic(
            client, pdf_bytes, model, pages,
            SUMMARY_SYSTEM_PROMPT, SUMMARY_USER_PROMPT, mode="summary",
        )

    try:
        return _call_anthropic(
            client, pdf_bytes, model, pages,
            SYSTEM_PROMPT, USER_PROMPT, mode="full",
        )
    except anthropic_pkg.BadRequestError as e:
        if not _is_content_filter_block(e):
            raise
        print(
            f"[parser] content filter blocked full extraction of {pdf_path.name}; "
            f"retrying in summary mode for fair-use academic reference",
            file=sys.stderr,
        )
        return _call_anthropic(
            client, pdf_bytes, model, pages,
            SUMMARY_SYSTEM_PROMPT, SUMMARY_USER_PROMPT, mode="summary",
        )


def _main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("pdf", type=Path, help="Path to PDF file")
    p.add_argument("--model", default=DEFAULT_MODEL)
    p.add_argument("--out", type=Path, help="Write markdown to this file (default: stdout)")
    p.add_argument(
        "--summary",
        action="store_true",
        help="Force summary mode (skip full extraction attempt). For fair-use academic reference.",
    )
    args = p.parse_args()

    if not args.pdf.exists():
        sys.exit(f"not found: {args.pdf}")

    result = parse_pdf(args.pdf, model=args.model, force_summary=args.summary)

    summary_label = f"mode={result.mode}"
    usage_label = f"{result.input_tokens} in / {result.output_tokens} out tokens"

    if args.out:
        args.out.write_text(result.markdown, encoding="utf-8")
        print(
            f"[parser] wrote {args.out} ({result.pages} pages, {summary_label}, "
            f"{usage_label}, model={result.model})",
            file=sys.stderr,
        )
    else:
        sys.stdout.write(result.markdown)
        print(
            f"\n\n[parser] {result.pages} pages, {summary_label}, "
            f"{usage_label}, model={result.model}",
            file=sys.stderr,
        )


if __name__ == "__main__":
    _main()
