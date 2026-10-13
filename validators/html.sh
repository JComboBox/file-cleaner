#!/usr/bin/env bash
# Validator for 'html': browsers accept almost anything, so check the failure
# mode cleaning can introduce — unbalanced <!-- --> comments.
set -uo pipefail
command -v python3 >/dev/null || exit 3
python3 -I - "$1" <<'PY'
import sys
src = open(sys.argv[1], encoding="utf-8", errors="replace").read()
depth, i = 0, 0
while True:
    o, c = src.find("<!--", i), src.find("-->", i)
    if o < 0 and c < 0:
        break
    if o >= 0 and (c < 0 or o < c):
        if depth:
            break  # nested opener inside a comment is literal text
        depth, i = 1, o + 4
    else:
        if not depth:
            sys.exit(f"{sys.argv[1]}: stray '-->' at offset {c}")
        depth, i = 0, c + 3
if depth:
    sys.exit(f"{sys.argv[1]}: unterminated comment")
PY
