# latex-safe-build

An [Agent Skill](https://code.claude.com/docs/en/skills) that teaches AI coding
agents to compile LaTeX **in an isolated scratch copy**, so a build can never
corrupt the document it is building.

## The problem

`latexmk` writes its intermediates (`.aux`, `.bcf`, `.toc`, ...) into the tree it
runs in. The moment anything else touches that tree during a build (an editor
saving a chapter, a second agent session, a file sync tool, another build), the
intermediates end up half-written and you get failures that look like source bugs:

- `File ended while scanning use of ...`
- biber crashing on a malformed `.bcf`
- sudden storms of "undefined reference" that were fine an hour ago
- a PDF assembled from a stale table of contents

This skill came out of a 127-page master's thesis written with multiple AI agent
sessions editing the tree concurrently. In-tree builds corrupted state repeatedly
(twice in one day, at the worst point); moving every build into an isolated copy
eliminated the failure class entirely, and the document shipped from this exact
workflow.

## What the skill does

- **Builds in isolation.** `scripts/safe-build.sh` rsyncs the project to a scratch
  directory (excluding regenerable artifacts, never your figure PDFs), runs
  `latexmk -halt-on-error` there, and copies only the finished PDF back. The
  working tree stays byte-identical except for the output.
- **Refuses to race.** It detects an already-running `latexmk` on the same
  document and stops, because overlapping builds are the corruption scenario.
- **Reports what matters.** After every build: a filtered list of genuinely
  unresolved references and citations (rerun/font noise stripped), plus both page
  counts via `scripts/text_pages.py`: total PDF pages **and** text pages
  (Introduction through Conclusion), because a 127-page PDF can be a 72-page
  thesis and page limits are counted on the latter.
- **Fixes float pathology.** `references/float-governance.md` carries a tested
  preamble block for deterministic float placement and targeted fixes for
  bare-heading sections and orphaned figure pages.
- **Triages failures.** `references/troubleshooting.md` maps the recurring failure
  patterns to their actual causes.

## Install

For [Claude Code](https://code.claude.com/docs/en/skills), as a personal skill:

```bash
git clone https://github.com/molanocortes/latex-safe-build ~/.claude/skills/latex-safe-build
```

Or copy the folder into `.claude/skills/` inside a project to share it with that
repo. The skill format is an open standard, so any agent that reads `SKILL.md`
(Codex, Cursor, Gemini CLI, ...) can use it too.

Requirements: a TeX distribution with `latexmk`, `rsync`, and optionally
`python3` + `pypdf` for the page-count report.

## Use it standalone

The scripts work without any AI agent:

```bash
scripts/safe-build.sh ~/thesis main.tex           # pdflatex
scripts/safe-build.sh ~/thesis main.tex -xelatex  # fontspec documents
scripts/text_pages.py ~/thesis/main.pdf --start "Chapter 1" --end "Bibliography"
```

## License

MIT
