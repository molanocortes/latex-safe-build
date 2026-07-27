#!/usr/bin/env python3
"""Report a PDF's total page count and its "text page" count.

Text pages are what universities and journals actually count: the span from the
first content chapter to the last page before the bibliography. Both numbers are
printed because reporting only the PDF total to someone with a page limit is
misleading (a 127-page PDF can be a 72-page thesis).

Usage:
    text_pages.py thesis.pdf
    text_pages.py thesis.pdf --start "1 Introduction" --end "References"
"""
import argparse
import sys


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("pdf")
    ap.add_argument("--start", default="Chapter 1",
                    help="text found on the first text page (default: 'Chapter 1')")
    ap.add_argument("--end", default="Bibliography",
                    help="text found on the first page AFTER the text pages "
                         "(default: 'Bibliography')")
    args = ap.parse_args()

    try:
        from pypdf import PdfReader
    except ImportError:
        print("text_pages.py: pypdf not installed (pip install pypdf); "
              "skipping page-count report", file=sys.stderr)
        return 0

    reader = PdfReader(args.pdf)
    pages = [(p.extract_text() or "") for p in reader.pages]
    total = len(pages)
    print(f"TOTAL PDF PAGES: {total}")

    start = next((i for i, t in enumerate(pages) if args.start in t), None)
    if start is None:
        print(f"start marker {args.start!r} not found; cannot count text pages. "
              f"Pass --start matching the first chapter heading.")
        return 1

    # The end marker is searched only after the start page so a table-of-contents
    # entry mentioning the bibliography cannot end the count early.
    end = next((i for i, t in enumerate(pages) if i > start and args.end in t), None)
    if end is None:
        print(f"end marker {args.end!r} not found after page {start + 1}; "
              f"counting to the last page instead.")
        end = total

    print(f"TEXT PAGES ({args.start!r} -> before {args.end!r}): {end - start}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
