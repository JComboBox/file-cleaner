"""Balanced-delimiter check for C-like sources, ignoring strings and comments."""
import sys

PAIRS = {")": "(", "]": "[", "}": "{"}


def check(src: str) -> str | None:
    stack, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            i = src.find("\n", i)
            i = n if i < 0 else i
        elif src.startswith("/*", i):
            j = src.find("*/", i + 2)
            if j < 0:
                return "unterminated block comment"
            i = j + 2
            continue
        elif c in "\"'":
            j = i + 1
            while j < n and src[j] != c and src[j] != "\n":
                j += 2 if src[j] == "\\" else 1
            i = j
        elif c in "([{":
            stack.append(c)
        elif c in PAIRS:
            if not stack or stack.pop() != PAIRS[c]:
                return f"unbalanced '{c}' at offset {i}"
        i += 1
    return f"unclosed '{stack[-1]}'" if stack else None


if __name__ == "__main__":
    err = check(open(sys.argv[1], encoding="utf-8", errors="replace").read())
    if err:
        print(f"{sys.argv[1]}: {err}", file=sys.stderr)
        sys.exit(1)
