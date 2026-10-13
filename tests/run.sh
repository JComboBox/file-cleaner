#!/usr/bin/env bash
# Test runner. Runs fixture cases (tests/cases/*) and end-to-end tests
# against throwaway local git repositories. Never touches the network.
#
# Usage: tests/run.sh [CASE_NAME_FILTER]
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$ROOT/tests/.tmp"
rm -rf "$TMP"; mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

# Isolate from any user config and credentials.
export FC_CONFIG=/dev/null FC_LOG_LEVEL="${FC_LOG_LEVEL:-error}"
unset FC_GIT_TOKEN GITHUB_TOKEN GITLAB_TOKEN FC_CONFIG_LOADED
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

filter="${1:-}"
pass=0 fail=0
ok()   { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; [[ -n "${2:-}" ]] && printf '%s\n' "$2" | sed 's/^/        /'; }

echo "fixture cases"
for dir in "$ROOT"/tests/cases/*/; do
  name="$(basename "$dir")"
  [[ -n "$filter" && "$name" != *"$filter"* ]] && continue
  inputs=("$dir"input.*); input="${inputs[0]}"
  ext="${input##*.}"
  want_status="$(cat "$dir/status")"
  work="$TMP/cases/$name"; mkdir -p "$work"
  cp "$input" "$work/file.$ext"

  got="$("$ROOT/scripts/fc-clean-file.sh" "$work/file.$ext" 2>"$work/stderr")"
  got_status="${got%%$'\t'*}"

  if [[ "$got_status" == unvalidated && "$want_status" == changed ]]; then
    got_status=changed
    echo "        (note: validator unavailable for $name)"
  fi
  if [[ "$got_status" != "$want_status" ]]; then
    bad "$name" "status: want '$want_status', got '$got_status'"$'\n'"$(cat "$work/stderr")"
  elif ! d="$(diff -u "$dir/expected.$ext" "$work/file.$ext")"; then
    bad "$name" "$d"
  else
    ok "$name"
  fi
done

[[ -n "$filter" ]] && { echo; echo "$pass passed, $fail failed"; (( fail == 0 )); exit; }

# --- end-to-end -------------------------------------------------------------

# make_remote NAME — bare repo seeded with sample files; prints its path.
make_remote() {
  local bare="$TMP/remotes/$1.git" seed="$TMP/seed/$1"
  git init --quiet --bare --initial-branch=main "$bare"
  git init --quiet --initial-branch=main "$seed"
  printf '#!/usr/bin/env bash\n# Copyright 2020 Example Corp.\n\necho hi\n' > "$seed/run.sh"
  printf '# Copyright 2020 Example Corp.\nprint("hi")\n' > "$seed/app.py"
  mkdir -p "$seed/node_modules/dep"
  printf '// Copyright 2020 Example Corp.\nmodule.exports = 1;\n' > "$seed/node_modules/dep/index.js"
  printf 'notes\n' > "$seed/README.txt"
  git -C "$seed" add -A
  git -C "$seed" -c user.name=t -c user.email=t@t commit --quiet -m seed
  git -C "$seed" push --quiet "$bare" main
  echo "$bare"
}

echo
echo "end-to-end"

remote="$(make_remote push)"
if out="$("$ROOT/bin/file-cleaner" -N -b fc/test -w "$TMP/work" "$remote" 2>&1)"; then
  if ! git -C "$remote" rev-parse --quiet --verify refs/heads/fc/test >/dev/null; then
    bad "push: branch reaches remote" "$out"
  elif git -C "$remote" show fc/test:app.py | grep -qi copyright; then
    bad "push: header removed from app.py" "$(git -C "$remote" show fc/test:app.py)"
  elif ! git -C "$remote" show fc/test:node_modules/dep/index.js | grep -qi copyright; then
    bad "push: excluded dirs untouched"
  elif [[ "$(git -C "$remote" show fc/test:run.sh | head -n1)" != '#!/usr/bin/env bash' ]]; then
    bad "push: shebang preserved"
  elif [[ "$(git -C "$remote" rev-parse main)" != "$(git -C "$TMP/seed/push" rev-parse HEAD)" ]]; then
    bad "push: default branch untouched"
  else
    ok "push: cleans, commits and pushes a branch; main untouched"
  fi
else
  bad "push: run succeeds" "$out"
fi

remote="$(make_remote dry)"
if out="$("$ROOT/bin/file-cleaner" -n -b fc/dry -m "chore: dry" -w "$TMP/work" "$remote" 2>&1)"; then
  if git -C "$remote" rev-parse --quiet --verify refs/heads/fc/dry >/dev/null; then
    bad "dry run: nothing pushed"
  elif [[ "$(git -C "$TMP/work/local/dry" log -1 --format=%s fc/dry 2>/dev/null)" != "chore: dry" ]]; then
    bad "dry run: local commit exists with -m message" "$out"
  else
    ok "dry run: commits locally, pushes nothing"
  fi
else
  bad "dry run: run succeeds" "$out"
fi

# A failed clone must stop that repo's pipeline. Run from inside another git
# repository: the later steps must not fall back to operating on it.
bystander="$TMP/bystander"
git init --quiet --initial-branch=main "$bystander"
printf '# Copyright 2020 Example Corp.\necho hi\n' > "$bystander/keep.sh"
git -C "$bystander" add -A
git -C "$bystander" -c user.name=t -c user.email=t@t commit --quiet -m seed
if out="$(cd "$bystander" && "$ROOT/bin/file-cleaner" -n -w "$TMP/work" "$TMP/does-not-exist.git" 2>&1)"; then
  bad "missing repo: exits non-zero" "$out"
elif [[ "$(git -C "$bystander" branch --format='%(refname:short)')" != main ]] \
  || ! grep -q Copyright "$bystander/keep.sh" \
  || [[ "$(git -C "$bystander" rev-list --count HEAD)" != 1 ]]; then
  bad "missing repo: leaves the current directory's repo untouched" \
    "$(git -C "$bystander" branch; git -C "$bystander" log --oneline)"
else
  ok "missing repo: exits non-zero, current repo untouched"
fi

for script in fc-branch.sh fc-clean.sh "fc-submit.sh --dry-run"; do
  # shellcheck disable=SC2086  # word-splitting $script into name + flag is intended
  if (cd "$bystander" && "$ROOT"/scripts/$script "" >/dev/null 2>&1); then
    bad "${script%% *}: rejects an empty repo dir"
  else
    ok "${script%% *}: rejects an empty repo dir"
  fi
done

# Refuse to commit on the default branch.
remote="$(make_remote guard)"
clone="$TMP/guard-clone"; git clone --quiet "$remote" "$clone"
if "$ROOT/scripts/fc-submit.sh" --dry-run "$clone" >/dev/null 2>&1; then
  bad "submit: refuses default branch"
else
  ok "submit: refuses default branch"
fi

# Merge request API calls, against a local mock server.
python3 -I "$ROOT/tests/mock_api.py" "$TMP/port" "$TMP/api.log" &
mock_pid=$!
trap 'kill "$mock_pid" 2>/dev/null; rm -rf "$TMP"' EXIT
for _ in $(seq 50); do [[ -s "$TMP/port" ]] && break; sleep 0.1; done
api="http://127.0.0.1:$(cat "$TMP/port")"

check_mr() { # NAME URL PROVIDER JQ_ASSERTION
  local name="$1" url="$2" provider="$3" assertion="$4" got
  : > "$TMP/api.log"
  got="$(FC_PROVIDER="$provider" FC_API_URL="$api" FC_GIT_TOKEN=s3cret \
    bash -c 'source "$1/lib/mr.sh"; load_config; open_merge_request "$2" fc/x main' _ "$ROOT" "$url" 2>&1)"
  if [[ "$got" == "http://mock/merge/1" ]] && jq -e "$assertion" "$TMP/api.log" >/dev/null; then
    ok "$name"
  else
    bad "$name" "$got"$'\n'"$(cat "$TMP/api.log")"
  fi
}
check_mr "mr: github pull request" https://github.com/acme/widgets.git auto \
  '.path == "/repos/acme/widgets/pulls" and .authorization == "Bearer s3cret" and .body.head == "fc/x" and .body.base == "main"'
check_mr "mr: gitlab merge request" https://gitlab.example.com/grp/sub/widgets.git auto \
  '.path == "/projects/grp%2Fsub%2Fwidgets/merge_requests" and .private_token == "s3cret" and .body.source_branch == "fc/x" and .body.target_branch == "main"'

echo
echo "$pass passed, $fail failed"
(( fail == 0 ))
