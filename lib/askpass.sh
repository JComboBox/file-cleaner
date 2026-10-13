#!/usr/bin/env bash
# GIT_ASKPASS helper: git calls this with a prompt; answer username or token.
case "$1" in
  Username*) printf '%s\n' "${FC_GIT_USERNAME:-oauth2}" ;;
  *)         printf '%s\n' "${FC_GIT_TOKEN:-${GITHUB_TOKEN:-${GITLAB_TOKEN:-}}}" ;;
esac
