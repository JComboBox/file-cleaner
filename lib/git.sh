#!/usr/bin/env bash
# Git authentication, clone, branch and push helpers.
#
# Authentication uses a token from $FC_GIT_TOKEN (or GITHUB_TOKEN /
# GITLAB_TOKEN) supplied to git through GIT_ASKPASS, so the token never
# appears in a remote URL, in .git/config, or in logs.

[[ -n "${_FC_GIT_LOADED:-}" ]] && return 0
_FC_GIT_LOADED=1

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# fc_token — print the token to use, if any.
fc_token() {
  printf '%s' "${FC_GIT_TOKEN:-${GITHUB_TOKEN:-${GITLAB_TOKEN:-}}}"
}

# git_login — configure non-interactive HTTPS auth for subsequent git calls.
git_login() {
  export GIT_TERMINAL_PROMPT=0
  if [[ -z "$(fc_token)" ]]; then
    log_debug "no token set; relying on existing git credentials / SSH agent"
    return 0
  fi
  export FC_GIT_USERNAME="${FC_GIT_USERNAME:-oauth2}"
  export GIT_ASKPASS="$FC_ROOT/lib/askpass.sh"
  log_debug "git auth: token via GIT_ASKPASS (user $FC_GIT_USERNAME)"
}

# detect_provider URL — github | gitlab | none (local/unknown).
detect_provider() {
  local url="$1"
  if [[ "$FC_PROVIDER" != "auto" ]]; then echo "$FC_PROVIDER"; return; fi
  case "$url" in
    *github.com[:/]*) echo github ;;
    *gitlab*)         echo gitlab ;;
    *)                echo none ;;
  esac
}

# repo_slug URL — "owner/name" (or "group/sub/name") from an https/ssh URL.
# Local paths and file:// URLs yield "local/<name>".
repo_slug() {
  local url="${1%/}"
  url="${url%.git}"
  if [[ "$url" == /* || "$url" == file://* || "$url" == .* ]]; then
    echo "local/${url##*/}"
    return
  fi
  url="${url#*://}"     # strip scheme
  url="${url#*@}"       # strip user@
  url="${url#*[:/]}"    # strip host
  echo "$url"
}

# repo_host URL — host part of an https/ssh URL.
repo_host() {
  local url="${1#*://}"
  url="${url#*@}"
  echo "${url%%[:/]*}"
}

# git_clone URL DEST — shallow-free clone (history needed for a clean push).
git_clone() {
  local url="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    log_info "reusing existing clone: $dest"
    git -C "$dest" fetch --quiet origin
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  log_info "cloning $url"
  git clone --quiet "$url" "$dest"
}

# default_branch REPO_DIR — the remote's default branch name.
default_branch() {
  local dir="$1" ref
  ref="$(git -C "$dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" \
    || ref="$(git -C "$dir" rev-parse --abbrev-ref HEAD)"
  echo "${ref#origin/}"
}

# git_branch REPO_DIR BRANCH [BASE] — create BRANCH from origin/BASE.
git_branch() {
  local dir="$1" branch="$2" base="${3:-}"
  [[ -n "$base" ]] || base="$(default_branch "$dir")"
  git check-ref-format --branch "$branch" >/dev/null || die "invalid branch name: $branch"
  log_info "creating branch $branch from $base"
  git -C "$dir" checkout --quiet -B "$branch" "origin/$base" 2>/dev/null \
    || git -C "$dir" checkout --quiet -B "$branch" "$base"
}

# git_commit_all REPO_DIR MESSAGE — commit all changes; returns 1 if none.
git_commit_all() {
  local dir="$1" msg="$2"
  git -C "$dir" add -A
  if git -C "$dir" diff --cached --quiet; then
    return 1
  fi
  git -C "$dir" \
    -c user.name="${FC_GIT_AUTHOR_NAME:-$(git -C "$dir" config user.name || echo file-cleaner)}" \
    -c user.email="${FC_GIT_AUTHOR_EMAIL:-$(git -C "$dir" config user.email || echo file-cleaner@localhost)}" \
    commit --quiet -m "$msg"
}

# git_push REPO_DIR BRANCH
git_push() {
  local dir="$1" branch="$2"
  log_info "pushing $branch"
  git -C "$dir" push --quiet -u origin "$branch"
}
