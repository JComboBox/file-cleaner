#!/usr/bin/env bash
# Open a merge request (GitLab) or pull request (GitHub) via the REST API.
# The token is passed to curl through a process-substitution header file so
# it never shows up in the process list.

[[ -n "${_FC_MR_LOADED:-}" ]] && return 0
_FC_MR_LOADED=1

# shellcheck source=lib/git.sh
source "$(dirname "${BASH_SOURCE[0]}")/git.sh"

# _fc_api METHOD URL HEADER_PREFIX [JSON_BODY] — authenticated API call;
# prints the response body. HEADER_PREFIX is e.g. "Authorization: Bearer";
# the token is appended after a space.
_fc_api() {
  local method="$1" url="$2" header="$3" body="${4:-}"
  local token
  token="$(fc_token)"
  [[ -n "$token" ]] || die "no API token: set FC_GIT_TOKEN (or GITHUB_TOKEN / GITLAB_TOKEN)"
  local args=(--silent --show-error --fail-with-body -X "$method"
              -H "Accept: application/json" -H "Content-Type: application/json")
  [[ -n "$body" ]] && args+=(--data "$body")
  # Process substitution must sit on the curl line itself to stay open.
  curl "${args[@]}" -H @<(printf '%s %s\n' "$header" "$token") "$url"
}

# open_merge_request URL SOURCE_BRANCH TARGET_BRANCH — prints the MR/PR web URL.
open_merge_request() {
  local url="$1" source="$2" target="$3"
  local provider host slug api resp
  provider="$(detect_provider "$url")"
  host="$(repo_host "$url")"
  slug="$(repo_slug "$url")"

  case "$provider" in
    github)
      if [[ -n "${FC_API_URL:-}" ]]; then api="$FC_API_URL"
      elif [[ "$host" == "github.com" ]]; then api="https://api.github.com"
      else api="https://$host/api/v3"; fi
      resp="$(_fc_api POST "$api/repos/$slug/pulls" "Authorization: Bearer" \
        "$(jq -n --arg t "$FC_MR_TITLE" --arg b "$FC_MR_DESCRIPTION" \
                 --arg h "$source" --arg base "$target" \
                 '{title:$t, body:$b, head:$h, base:$base}')")" \
        || { log_error "GitHub PR creation failed: $resp"; return 1; }
      jq -r '.html_url' <<<"$resp"
      ;;
    gitlab)
      api="${FC_API_URL:-https://$host/api/v4}"
      local id
      id="$(jq -rn --arg s "$slug" '$s|@uri')"
      resp="$(_fc_api POST "$api/projects/$id/merge_requests" "PRIVATE-TOKEN:" \
        "$(jq -n --arg t "$FC_MR_TITLE" --arg d "$FC_MR_DESCRIPTION" \
                 --arg s "$source" --arg tb "$target" \
                 '{title:$t, description:$d, source_branch:$s, target_branch:$tb, remove_source_branch:true}')")" \
        || { log_error "GitLab MR creation failed: $resp"; return 1; }
      jq -r '.web_url' <<<"$resp"
      ;;
    none)
      log_warn "no hosting provider for $url; branch pushed, open the merge request manually"
      ;;
    *)
      die "unknown provider: $provider (expected github, gitlab, none)"
      ;;
  esac
}
