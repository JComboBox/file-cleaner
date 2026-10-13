# AGENTS.md

Guidance for AI coding agents working on **file-cleaner**. Humans should
start with [README.md](README.md). Directories may contain their own
`AGENTS.md`; the one closest to the file you are editing takes precedence.

## Project overview

file-cleaner is a set of Bash utilities that, for each target repository:

1. **authenticates** to the git host (token via `GIT_ASKPASS`) — `lib/git.sh`
2. **clones** the repository — `scripts/fc-clone.sh`
3. **creates a work branch** from the default branch — `scripts/fc-branch.sh`
4. **walks tracked files** and, per file type, **removes headers and code
   snippets** — `scripts/fc-clean.sh` → `scripts/fc-clean-file.sh` → `cleaners/<type>.sh`
5. **validates** each changed file and reverts it if invalid — `validators/<type>.sh`
6. **commits, pushes, and opens a merge/pull request** — `scripts/fc-submit.sh`, `lib/mr.sh`

`bin/file-cleaner` runs steps 1–6 for every repository given.

## Layout

```
bin/file-cleaner        orchestrator (entry point)
scripts/fc-*.sh         one script per pipeline step; each usable standalone
lib/common.sh           logging, die, require_cmd, load_config (all FC_* defaults)
lib/filetypes.sh        extension/shebang → type mapping
lib/clean.sh, clean.awk generic cleaning engine (header, snippet, pattern removal)
lib/validate.sh         validator dispatch and exit-code contract
lib/git.sh, askpass.sh  auth, clone, branch, commit, push
lib/mr.sh               GitHub PR / GitLab MR creation via REST
cleaners/<type>.sh      per-type comment syntax, calls fc_clean
validators/<type>.sh    per-type syntax check
rules/<type>.patterns   per-type EREs; matching lines are deleted
config/*.example        config and repo-list templates
tests/run.sh            the test suite; tests/cases/<name>/ are fixtures
```

## Setup

Requirements: bash ≥ 4.4, git, awk (mawk or gawk — keep it POSIX), jq, curl,
python3. Optional validators: node, tsc, gofmt, xmllint, PyYAML/yamllint.

```sh
pip install shellcheck-py   # provides shellcheck for `make lint`
```

## Commands

```sh
make check            # lint + test — run before every commit
make lint             # shellcheck -x on all shell files
make test             # tests/run.sh
tests/run.sh python   # only fixture cases whose name contains "python"
FC_LOG_LEVEL=debug tests/run.sh   # verbose
```

Try the pipeline without touching a real remote:

```sh
bin/file-cleaner -n -w .work /path/to/local/repo.git   # -n = dry run
```

## Safety rules (must follow)

- **Never push to, or open an MR against, a real remote while developing.**
  Use `-n` (dry run), local bare repositories, or `tests/mock_api.py`.
  Only run without `-n` when the user explicitly asks for it.
- **Never write tokens** into files, URLs, commit messages, logs, or command
  arguments. Tokens come only from `FC_GIT_TOKEN` / `GITHUB_TOKEN` /
  `GITLAB_TOKEN` in the environment and reach git via `lib/askpass.sh` and
  curl via a process-substitution header.
- Never commit on, or push to, a repository's default branch.
  `fc-submit.sh` refuses; do not remove that guard.
- A cleaned file must be either **validated or reverted**. Do not add a code
  path that keeps a change that failed validation.
- Tests must not use the network or the user's git config (`tests/run.sh`
  sets `GIT_CONFIG_GLOBAL=/dev/null`).

## Code style

- Every executable starts with `#!/usr/bin/env bash` and `set -euo pipefail`
  (validators use `set -uo pipefail` because they map exit codes themselves).
- Must pass `shellcheck -x` with no findings. Do not add `# shellcheck
  disable=` without a comment explaining why.
- Libraries in `lib/` are sourced, guarded by `_FC_*_LOADED`, and define
  functions only — no side effects at source time beyond setting `FC_ROOT`.
- Log with `log_debug|info|warn|error` (stderr). Keep stdout for
  machine-readable output (status lines, paths, MR URLs).
- All tunables are `FC_*` variables with defaults in `load_config`; document
  new ones in `config/file-cleaner.conf.example` and README.md.
- `set -e` is ignored inside anything run as an `if`/`&&`/`||` condition
  (including functions and subshells). Check each step's status explicitly
  there, as `process_repo` in `bin/file-cleaner` does.
- Scripts that take a repo directory must call `require_repo_dir` first, so
  an empty path never falls back to the current directory's repository.
- Quote every expansion. Prefer `[[ ]]`, `$(...)`, arrays for argument lists.
- awk must stay POSIX (mawk is the default on Debian/Ubuntu): no `gensub`,
  `IGNORECASE`, or `--re-interval`. Pass regexes via `ENVIRON`, not `-v`.
- 2-space indentation (see `.editorconfig`).

## Contracts

`scripts/fc-clean-file.sh` prints `STATUS<TAB>TYPE<TAB>FILE`, STATUS one of
`changed | unchanged | reverted | unvalidated | skipped | error`.

Validators exit `0` valid, `1` invalid, `3` no tool available.

Cleaners take one file path, edit in place, exit non-zero on failure (the
caller restores the original).

## Common tasks

**Add a file type** — see [cleaners/AGENTS.md](cleaners/AGENTS.md).

**Change what counts as a header** — `FC_HEADER_PATTERN` (lowercase ERE,
matched against the lowercased leading comment block).

**Remove a code pattern** — add an anchored ERE to `rules/<type>.patterns`
and a fixture under `tests/cases/` that proves it.

**Support another git host** — add a branch to `detect_provider` in
`lib/git.sh` and to `open_merge_request` in `lib/mr.sh`; add a `check_mr`
case in `tests/run.sh` using the mock server.

## Testing

- Every behavior change needs a test. Fixture case = a directory
  `tests/cases/<name>/` with `input.<ext>`, `expected.<ext>`, and `status`
  (the expected STATUS word). Name cases `<type>-<behavior>`.
- Cover both directions: content that should be removed and similar content
  that must be kept (e.g. a non-license comment, a JSDoc block).
- End-to-end tests in `tests/run.sh` build throwaway bare repos under
  `tests/.tmp/`; follow the `make_remote` pattern.

## CI and branch protection

- `.github/workflows/ci.yml` runs `make check` as the `regression-tests`
  job on every pull request and on pushes to `main`.
- `main` is protected by `.github/rulesets/main.json`: changes land only
  through a pull request whose `regression-tests` check passed on a branch
  that is up to date with `main`; force-pushes and deletion are blocked.
- Renaming the CI job breaks the required check — update the ruleset in the
  same PR and re-apply it (see README.md).

## Commits and pull requests

- Conventional Commits: `feat:`, `fix:`, `test:`, `docs:`, `chore:`.
- `make check` must pass before committing.
- Keep PRs focused: one file type or one pipeline step per PR where possible.
