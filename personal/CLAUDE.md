# personal/ — vault rules

Personal knowledge base. Articles, X posts, blogs, reference material on home, family, finance, health, travel, hobbies, and personal AI explorations. Terse style — this is private; no need for formal citations.

## Vault scope

In: anything you'd save to read later that isn't work/teaching. AI explorations on the personal side (toys, hobby projects) live here, not in `work/`.

Out: anything tied to <your-org>, teaching, courses, or research-as-job. Those go in `work/`.

If unclear, drop in the top-level `brainiac/aa-inbox/` and let `/kb` propose a vault.

## Summary template (terse)

For each captured item, `_summary.md` is roughly:

```markdown
---
source: <URL or file path>
captured: YYYY-MM-DD
type: article | pdf | tweet | note | image
---

# <Title>

**TL;DR:** one to two sentences.

## Why I saved it
- one or two bullets

## Key takeaways
- bullet
- bullet

## Notes
free-form, optional
```

No formal citation block. No author-year apparatus. Just enough context to answer "why did I save this and what's worth remembering."

## Privacy opt-out

Any folder named `materials/` is **not indexed** by `/kb`. Use it for raw sensitive docs (tax filings, medical records, legal correspondence) you want to keep in the vault but never expose to a Q&A query. Summary/topic-list scans skip these folders entirely.

## Topic folders (will accrete naturally)

Don't pre-create folders. As items get processed, `/kb` proposes a folder for each new topic. Likely emergents over time:

- `ai/` — personal AI experiments, hobby projects, coding notes, AI tooling, Claude usage tips. **Preferred name:** `ai/` (not `ai-development/`, `ai-tools/`, etc. — keep it simple).
- `investments/` — TIPS, I-bonds, brokerage decisions, market commentary
- `home/` — house projects, repairs, vendors
- `health/` — fitness, sleep, diet, medical research (with `materials/` for records)
- `travel/` — trip planning, logistics, things to do
- `taxes/` — annual filing notes (with `materials/` for filings)
- `family/` — kid stuff, school, extended-family logistics

## Capture workflow for X (Twitter) content

X.com tweets and long-form articles are **login-gated** — the URL-drop Shortcut ("Add to Brainiac" → `urls.txt`) does not work for them because the backend fetch can't authenticate.

**Use Obsidian Web Clipper instead** for X content:
1. Open the tweet/article in Safari (already logged in to X).
2. Tap Share → Obsidian Web Clipper → personal vault → `aa-inbox/`.
3. Web Clipper extracts content from the DOM (respects your logged-in session), saves a `.md` file with the URL in frontmatter.

This is the same path as for any web article. The URL-drop Shortcut should be reserved for publicly-accessible URLs that backend WebFetch can resolve.

## Style

- First-person fine.
- Informal language fine.
- No need for APA citations.
- No need for institutional context.
