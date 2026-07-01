# work/ — vault rules

<your-org> / teaching / institutional knowledge base. Articles, papers, case sources, pedagogy notes, AI-in-education material, course materials pulled from OneDrive. **APA-style citation block** required on every summary.

## Vault scope

In: <your-org> research, teaching pedagogy, course-specific material, AI-in-education content, institutional KB context, academic papers, <your-org>-relevant blog posts.

Out: personal AI hobby projects, home/finance/health, family. Those go in `personal/`.

Cross-references to other institutional surfaces live in `crossrefs.md`. (If you keep teaching/course material in an external store, you can also maintain a metadata-only `course-archive-index.md` — see the reference setup's `/kb archive scan` mode.)

## Summary template (APA-aware)

For each captured item, `_summary.md` is roughly:

```markdown
---
source: <URL or file path>
captured: YYYY-MM-DD
type: article | pdf | paper | case | slides | exercise | image
authors: <Last, F.M.; Last, F.M.>
year: <YYYY>
publication: <Journal / Outlet / Internal>
---

# <Title>

**Citation (APA):**
> Last, F. M., & Last, F. M. (YYYY). Title. *Publication*. URL or DOI.

**TL;DR:** one to two sentences.

## Relevance to <your-org> / teaching
- one or two bullets — which course(s), which framework, which research question

## Key arguments
- bullet
- bullet
- bullet

## Quotable passages
- "..." (page or paragraph reference)

## Connections
- Related items in this vault: `[[YYYY-MM-DD AuthorOrSource. Title]]`
- Related external: see `crossrefs.md` if it points elsewhere
```

## Topic folders (will accrete naturally)

Don't pre-create folders. Likely emergents over time:

- `ai-teaching/` — AI in business education, AI literacy curriculum
- `courses/` — per-course subfolders: `course-101/`, `course-202/`, etc.
- `cases/` — case sources, teaching notes, discussion guides
- `pedagogy/` — pedagogical research, case-method guidance, evaluation methods
- `org-context/` — institutional context, faculty research, programmatic decisions
- `outputs/` (defer) — your own writing, syntheses, drafts

## Cross-reference behavior

When `/kb ask` runs in this vault:

1. Answer from `work/index.md` + summaries first.
2. If external context is needed, read `crossrefs.md` to identify the right surface.
3. **Ask before reading** from any external surface (`<your-research-kb>/`, OneDrive, `Claude Working/`, `big-ideas/`).
4. For OneDrive specifically: prefer `course-archive-index.md` (metadata only) before reading individual files.

## Privacy opt-out

`materials/` folders are not indexed (same as personal vault). Use for confidential institutional documents that should stay in the vault but never surface in Q&A.

## Style

- Third-person, professional register acceptable but not required.
- APA citation block always present.
- Quote sparingly with page/paragraph reference.
- Preserve original terminology — don't paraphrase technical terms.
