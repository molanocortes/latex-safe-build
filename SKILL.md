---
name: latex-safe-build
description: Compile LaTeX documents in an isolated copy so the build can never corrupt the source tree, then report unresolved references and the page counts that actually matter (text pages, not just PDF pages). Use this skill whenever building or compiling any LaTeX document (latexmk, pdflatex, xelatex, lualatex, biber), whenever a build fails with corrupted .aux/.bcf files or "File ended while scanning" errors, whenever more than one session, agent, or person might touch the same LaTeX tree, when the user asks how long a thesis, report, or paper is in pages, or when hunting undefined references and citations. Even a plain "compile my thesis" or "rebuild the PDF" should go through this skill.
---

# latex-safe-build

Build LaTeX documents without ever running the compiler inside the working tree.

## Why this exists

`latexmk` writes dozens of intermediate files (`.aux`, `.bcf`, `.toc`, `.fls`, ...)
into the directory it runs in. If anything else touches that directory during the
build (an editor saving a chapter, another agent session, a file sync tool, a second
build), the intermediates end up half-written. The symptoms are confusing and look
like source errors: `File ended while scanning use of ...`, biber crashing on a
malformed `.bcf`, phantom "undefined reference" storms, or a PDF built from a stale
table of contents. On a large multi-session thesis this failure mode happened
repeatedly; building in an isolated copy eliminated it completely.

The rule, always: **copy the tree to a scratch location, build there, copy only the
final PDF back.** The working tree stays byte-identical except for the output.

## How to build

Use the bundled script. It implements the whole discipline in one call:

```bash
scripts/safe-build.sh <source-dir> [main-tex] [engine-flag]
```

- `source-dir`: the LaTeX project root.
- `main-tex`: the root file, default `main.tex`.
- `engine-flag`: passed to latexmk. Default `-pdf` (pdflatex); use `-xelatex` or
  `-lualatex` when the preamble needs it (fontspec is the usual tell).

What it does, in order:

1. Refuses to run if another `latexmk` on the same document is already running.
   Racing a live build is exactly the corruption scenario this skill prevents.
2. `rsync`s the tree to `$TMPDIR/latex-safe-build/<project>/`, excluding only
   regenerable artifacts (`.aux`, `.bcf`, `.toc`, `.bbl`, the root output PDF, ...).
   It never excludes `*.pdf` globally, because vector figures are PDFs and they are
   content, not artifacts.
3. Runs `latexmk -interaction=nonstopmode -halt-on-error` in the copy, logging to
   `$TMPDIR/latex-safe-build/<project>.log`. On failure it prints the log tail.
4. Copies the finished PDF back into the source tree.
5. Prints a filtered list of unresolved references (undefined and multiply defined
   labels and citations, with rerun/font noise stripped out).
6. Reports page counts via `scripts/text_pages.py` when `pypdf` is available.

If the build fails, read the log tail it prints before opening the full log; the
tail almost always contains the actual error. See
`references/troubleshooting.md` for the recurring failure patterns and what each
one actually means.

## Page counts: report the number that matters

A PDF page count and a document length are different numbers. Universities and
journals count **text pages** (typically Introduction through Conclusion), while
`pdfinfo` counts everything including the title page, table of contents, bibliography
and appendices. A 127-page PDF can be a 72-page thesis. Reporting the wrong one to a
user who is up against a page limit is a serious error, so always report both:

```bash
scripts/text_pages.py <pdf> --start "Chapter 1" --end "Bibliography"
```

The markers are configurable because document classes differ (`"1 Introduction"`,
`"Kapitel 1"`, `"References"`, ...). If the defaults find nothing, look at the
actual headings in the PDF and pass matching markers rather than guessing.

## Before rebuilding after a failure

A failed or interrupted build can leave the scratch copy in a bad state. The script
already starts from a clean copy every run, but if you ever build manually:

- delete the scratch build directory entirely (`rm -rf`, it contains nothing
  original), and
- confirm no `latexmk` process is still alive (`pgrep -fl latexmk`) before starting
  a new one. Two overlapping latexmk runs on one document produce corrupt
  intermediates even in a scratch directory.

Never "fix" a broken build by deleting `.aux` files inside the working tree; that
treats the symptom in the wrong place and destroys state other tools may be using.
The working tree should never have been built in to begin with.

## Float and layout problems

Build races are not the only thing that silently degrades a large document. If the
user reports figures drifting far from their references, sections rendering as a
bare heading with no body, or a lone figure stranded on its own page, read
`references/float-governance.md`. It contains a tested preamble block that makes
float placement deterministic, plus targeted fixes for the two common orphan
patterns. Apply it when diagnosing layout, not preemptively on healthy documents.

## Scope boundaries

This skill governs how to *build* and *diagnose* LaTeX projects. It does not write
or restructure LaTeX content, choose document classes, or manage bibliographies
beyond reporting unresolved citations. For a quick single-file compile of a
throwaway snippet with nothing else touching the directory, a direct `pdflatex`
call is fine; the isolation discipline earns its keep the moment a document has a
working tree worth protecting.
