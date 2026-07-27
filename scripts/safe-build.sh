#!/bin/sh
# safe-build.sh -- compile a LaTeX tree in an isolated scratch copy so the
# build can never corrupt the working tree.
#
# Usage: safe-build.sh <source-dir> [main-tex] [engine-flag]
#   source-dir   LaTeX project root
#   main-tex     root .tex file, default: main.tex
#   engine-flag  passed to latexmk: -pdf (default), -xelatex, -lualatex
set -e

SRC=$(cd "${1:?usage: safe-build.sh <source-dir> [main-tex] [engine-flag]}" && pwd)
MAIN="${2:-main.tex}"
ENGINE="${3:--pdf}"
BASE="${MAIN%.tex}"
NAME=$(basename "$SRC")
SCRATCH="${TMPDIR:-/tmp}/latex-safe-build"
BLD="$SCRATCH/$NAME"
LOG="$SCRATCH/$NAME.log"

[ -f "$SRC/$MAIN" ] || { echo "error: $SRC/$MAIN not found" >&2; exit 1; }

# latexmk may live outside the default PATH (common on macOS with MacTeX).
command -v latexmk >/dev/null 2>&1 || PATH="/Library/TeX/texbin:/usr/local/texlive/2026/bin/universal-darwin:$PATH"
command -v latexmk >/dev/null 2>&1 || { echo "error: latexmk not found on PATH" >&2; exit 1; }

# Refuse to race a live build: overlapping latexmk runs on the same document
# are the corruption scenario this script exists to prevent.
if pgrep -f "latexmk.*$BASE" >/dev/null 2>&1; then
  echo "error: another latexmk for '$BASE' is running (pgrep -fl latexmk). Refusing to race it." >&2
  exit 2
fi

# Fresh scratch copy every run. Exclude only regenerable artifacts. Never
# exclude *.pdf globally: vector figures are PDFs and they are content.
rm -rf "$BLD"
mkdir -p "$BLD"
rsync -a \
  --exclude="/$BASE.pdf" \
  --exclude='*.aux' --exclude='*.bcf' --exclude='*.bbl' --exclude='*.blg' \
  --exclude='*.fdb_latexmk' --exclude='*.fls' --exclude='*.synctex.gz' \
  --exclude='*.toc' --exclude='*.lof' --exclude='*.lot' --exclude='*.out' \
  --exclude='*.run.xml' --exclude='.git' \
  "$SRC/" "$BLD/"

cd "$BLD"
latexmk "$ENGINE" -interaction=nonstopmode -halt-on-error "$MAIN" >"$LOG" 2>&1 || {
  echo "BUILD FAILED - tail of $LOG:"
  tail -40 "$LOG"
  exit 1
}

cp "$BLD/$BASE.pdf" "$SRC/$BASE.pdf"
echo "BUILD OK -> $SRC/$BASE.pdf"

echo "--- unresolved references ---"
grep -iE "undefined|multiply defined" "$BLD/$BASE.log" \
  | grep -ivE "rerun|font|shape" | head -30 || echo "none"

# Page-count report (optional: needs python3 + pypdf).
DIR=$(cd "$(dirname "$0")" && pwd)
if command -v python3 >/dev/null 2>&1 && [ -f "$DIR/text_pages.py" ]; then
  python3 "$DIR/text_pages.py" "$SRC/$BASE.pdf" || true
fi
