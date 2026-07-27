# Troubleshooting LaTeX builds

Recurring failure patterns, what they actually mean, and the fix. Read the tail of
the build log first; the real error is almost always in the last 40 lines.

## "File ended while scanning use of ..."

An intermediate file (usually `.aux` or `.toc`) was half-written when the compiler
read it. Classic symptom of a build racing an editor save, a sync tool, or another
build. Fix: delete the scratch build directory and rebuild from a fresh copy. If it
recurs, something is writing into the build directory while latexmk runs; find it
before rebuilding. If the truncated file is a `.tex` source, the source itself is
damaged: check it in the working tree.

## biber: "data source ... .bcf could not be read" or malformed .bcf

The `.bcf` handoff file between latex and biber is stale or corrupt, same root cause
as above. Fix: fresh scratch copy. Never delete `.bcf`/`.aux` inside the working
tree to "fix" this; the working tree should not contain build artifacts at all.

## A storm of undefined references that were fine yesterday

Usually not a source problem: the `.aux` state is stale or a required rerun did not
happen. latexmk handles reruns automatically, so a fresh isolated build resolves it.
Only if the *fresh* build still reports them are they real; then the filtered list
printed by `safe-build.sh` is the actual to-do list.

## Build hangs or two builds interleave

Check `pgrep -fl latexmk`. Two latexmk processes on the same document corrupt each
other even in a scratch directory. Kill both, delete the scratch copy, rebuild once.
`safe-build.sh` refuses to start when it detects this, so a hang here usually means
a previous run never exited.

## "! LaTeX Error: File 'x.sty' not found"

Missing package. On TeX Live: `tlmgr install <package>`. On MacTeX the binaries live
in `/Library/TeX/texbin`, which may not be on PATH for non-login shells; the build
script prepends it automatically.

## Engine mismatch (fontspec, unicode errors)

`fontspec` and system-font setups require XeLaTeX or LuaLaTeX. If the log shows
`fontspec error` or `Unicode character ... not set up`, rebuild with `-xelatex` or
`-lualatex` instead of the default `-pdf`.

## The PDF built but looks stale

Confirm you are looking at the PDF the script copied back (working tree root), not
an old artifact somewhere else, and check the PDF modification time. If the working
tree contained a committed output PDF, the script overwrites it in place, which is
the intended behavior.

## Page count changed unexpectedly

Before blaming content edits, rebuild twice from clean scratch copies; a stale
`.toc`/`.lof` can shift front matter by a page. If the count difference is real and
you need to know where it came from, diff the two builds' `.toc` files.
