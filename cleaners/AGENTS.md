# AGENTS.md — cleaners/

Applies to `cleaners/`, `validators/`, `rules/`, and `lib/filetypes.sh`.
The root [AGENTS.md](../AGENTS.md) still applies.

## Adding a file type

1. **Detect it** — map extensions (and shebangs, if relevant) to a new type
   name in `detect_type` in `lib/filetypes.sh`. Type names are lowercase,
   hyphenated (`c-family`).
2. **Cleaner** — copy the closest `cleaners/<type>.sh` and set its comment
   syntax for `fc_clean`:
   - `--line REGEX` line comment, e.g. `'^[[:space:]]*--'`
   - `--block-start REGEX` / `--block-end REGEX` block comments
   - `--keep REGEX` leading lines that must survive (shebang, XML
     declaration, encoding pragma, doctype)
   Regexes are POSIX ERE in single quotes.
3. **Validator** — `validators/<type>.sh FILE`, exit 0/1/3 (see
   `validators/README.md`). It must be read-only: no formatting in place, no
   build artifacts. If the only available check is weak, say so in a comment.
4. **Rules** — create `rules/<type>.patterns` (comments only is fine).
5. **Tests** — at least two fixture cases in `tests/cases/`: one where a
   header is removed (`changed`) and one where a similar non-header comment
   is kept (`unchanged`).
6. `chmod +x` the new scripts, run `make check`, and update the supported
   types table in README.md.

## How cleaning works (lib/clean.awk)

Order of operations on each file:

1. Delete inclusive blocks between lines containing `FC_SNIPPET_BEGIN` and
   `FC_SNIPPET_END` (literal match). An unterminated block is an error and
   the file is left untouched.
2. Delete lines matching any ERE in `rules/<type>.patterns`.
3. Preserve leading `--keep` lines, then take the first comment block after
   any blank lines as the header candidate. Remove it (and trailing blank
   lines) only if its lowercased text matches `FC_HEADER_PATTERN`.

Only the *first* comment block is ever considered a header. Do not extend
header removal into the body of a file — that is what snippet markers and
pattern rules are for.

## Pitfalls

- awk always emits a final newline; `fc_clean` trims it again when the
  original file had none, so files are rewritten only when real content
  changes. Keep that behavior.
- Python docstrings are code, not comments; module-docstring license
  headers are not removed by the default python cleaner.
- `/* ... */` blocks that close on the opening line are handled; nested block
  comments (Rust, Swift) are not.
