# file-cleaner

Bash utilities that sweep git repositories for unwanted file headers (license
banners, copyright notices) and code snippets, remove them, verify each
changed file is still valid, and open a merge request with the result.

For each repository, `bin/file-cleaner`:

1. authenticates (token via `GIT_ASKPASS`, or your existing SSH/credential setup)
2. clones the repository
3. creates a work branch from the default branch
4. walks every tracked file and runs the cleaner for its type
5. validates each changed file — **files that fail validation are reverted**
6. commits, pushes the branch, and opens a GitHub PR or GitLab MR

To set it up on a machine, see [Installation](#installation). AI agents:
see [AGENTS.md](AGENTS.md).

## Installation

file-cleaner runs straight from a clone of this repository; there is
nothing to build or install. To use it on another machine:

**1. Install the prerequisites**

```sh
# Debian / Ubuntu
sudo apt-get install -y git jq curl python3
```

file-cleaner is developed and tested on Linux and needs bash 4.4 or newer.
macOS is untested: its built-in bash is 3.2 (too old) and it may lack
GNU tools the scripts use, such as `truncate`.

Optional, for validating more file types: `node`, `tsc`, `gofmt`,
`xmllint` (`libxml2-utils`), PyYAML or `yamllint`. See
[Supported types](#supported-types).

**2. Clone the repository**

```sh
git clone https://github.com/JComboBox/file-cleaner.git
# or over SSH
git clone git@github.com:JComboBox/file-cleaner.git
cd file-cleaner
```

If the repository is private, the machine needs read access to it first:
a GitHub login (e.g. `gh auth login`), an SSH key added to your account,
or a personal access token used when git prompts for a password. This
access is only for downloading the tool. The token file-cleaner uses
on the repositories it cleans is separate (`FC_GIT_TOKEN`; see
[Configuration](#configuration)).

**3. Check it works**

```sh
bin/file-cleaner -h      # prints usage
make test                # optional: runs the offline test suite
```

The scripts keep their executable bit through git, so no `chmod` is
needed.

**4. (Optional) Run it from anywhere**

Add the clone's `bin/` directory to your `PATH`, e.g. in `~/.bashrc`:

```sh
export PATH="$HOME/file-cleaner/bin:$PATH"   # adjust to where you cloned it
```

Do not symlink `bin/file-cleaner` into another directory: it finds its
`lib/` and `scripts/` relative to its own location, so a symlink breaks
it. Keep the clone in one piece and call the script in place.

**Updating**

```sh
git -C ~/file-cleaner pull
```

For repeatable runs across machines, check out the same commit or tag
everywhere (`git checkout <tag-or-sha>`) instead of tracking `main`.

## Quick start

```sh
export FC_GIT_TOKEN=...            # GitHub or GitLab token with repo/api scope

# Dry run first: clean and commit locally, push nothing.
bin/file-cleaner -n https://github.com/acme/widgets.git
git -C /tmp/file-cleaner/acme/widgets show --stat

# For real, across a list of repositories.
cp config/repos.txt.example config/repos.txt   # edit it
bin/file-cleaner -b chore/remove-license-headers -f config/repos.txt
```

## Options

```
bin/file-cleaner [options] REPO_URL...
bin/file-cleaner [options] -f REPOS_FILE

  -f FILE      read repository URLs from FILE
  -b BRANCH    work branch name
  -m MESSAGE   commit message and MR title
  -t TYPES     only these types, comma-separated (e.g. shell,python)
  -w DIR       where to clone (default /tmp/file-cleaner)
  -c FILE      config file (default config/file-cleaner.conf)
  -n           dry run — never push
  -N           push the branch but do not open an MR
  -v           debug logging
```

Every step is also a standalone script:

| Script                      | Does                                          |
|-----------------------------|-----------------------------------------------|
| `scripts/fc-clone.sh URL [DEST]`        | authenticate and clone; prints DEST |
| `scripts/fc-branch.sh DIR [BRANCH]`     | branch from the remote default branch |
| `scripts/fc-clean.sh DIR`               | clean + validate all tracked files |
| `scripts/fc-clean-file.sh FILE`         | clean + validate one file |
| `scripts/fc-submit.sh [--dry-run] DIR`  | commit, push, open MR |

## What gets removed

- **Headers** — the first comment block in a file (after a shebang, XML
  declaration, encoding line, or doctype, which are kept) if it matches
  `FC_HEADER_PATTERN`. Default:
  `copyright|all rights reserved|licensed under|spdx-license-identifier`.
- **Marked snippets** — everything from a line containing
  `FILE-CLEANER: BEGIN-REMOVE` through a line containing
  `FILE-CLEANER: END-REMOVE`, in any language.
- **Pattern lines** — lines matching an ERE in `rules/<type>.patterns`
  (e.g. stray `console.log` or `breakpoint()` calls; examples included,
  all disabled by default).

## Supported types

| Type         | Extensions                          | Validator                       |
|--------------|-------------------------------------|---------------------------------|
| shell        | `.sh .bash`, bash/sh shebang        | `bash -n`                       |
| python       | `.py`, python shebang               | `ast.parse`                     |
| javascript   | `.js .mjs .cjs`, node shebang       | `node --check`                  |
| typescript   | `.ts .tsx .jsx`                     | `tsc` (syntax errors only)      |
| go           | `.go`                               | `gofmt -e`                      |
| c-family     | `.c .h .cpp .java .cs .kt .rs ...`  | balanced delimiters (heuristic) |
| json         | `.json`                             | `jq empty`                      |
| yaml         | `.yml .yaml`                        | yamllint or PyYAML              |
| xml          | `.xml .xsd .pom .csproj`            | `xmllint --noout`               |
| html         | `.html .htm`                        | balanced `<!-- -->`             |

When a validator's tool is not installed the change is kept and logged as
`unvalidated`; set `FC_REQUIRE_VALIDATOR=1` to revert instead.

## Configuration

Copy `config/file-cleaner.conf.example` to `config/file-cleaner.conf`
(git-ignored). Command-line flags override it. Tokens belong in the
environment only: `FC_GIT_TOKEN`, or `GITHUB_TOKEN` / `GITLAB_TOKEN`.
Self-hosted GitLab or GitHub Enterprise: set `FC_PROVIDER` and, if needed,
`FC_API_URL`.

## Requirements

bash ≥ 4.4, git, awk, jq, curl, python3. Optional: node, tsc, gofmt,
xmllint, PyYAML or yamllint.

## Development

```sh
pip install shellcheck-py
make check      # shellcheck + tests (offline; uses local repos and a mock API)
```

## Branch protection

`main` only accepts changes through pull requests that pass the
`regression-tests` CI job (`make check`), with the branch up to date with
`main`. Force-pushes and branch deletion are blocked. The rules are kept in
`.github/rulesets/main.json`. To apply or update them, a repository admin runs:

```sh
gh api -X POST repos/JComboBox/file-cleaner/rulesets --input .github/rulesets/main.json
```

Or go to **Settings → Rules → Rulesets → New ruleset → Import a ruleset**
and choose the file. (To update an existing ruleset, use
`-X PUT repos/JComboBox/file-cleaner/rulesets/<id>`.)
