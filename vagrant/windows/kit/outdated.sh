#!/usr/bin/env bash
# Lists apps whose upstream has a newer release than the one locked (run on the host).
# To update: bump "version" (and "tag" where it's literal) in packages.json, then
# `just lock`. Python and npm deps move with `just lock --upgrade`.
set -euo pipefail
cd "$(dirname "$0")"

jq -r '.apps[] | select(.repo) | [.name, .repo, .tag] | @tsv' packages.lock.json |
  while IFS=$'\t' read -r name repo tag; do
    latest=$(gh api "repos/$repo/releases/latest" --jq .tag_name 2>/dev/null || echo '?')
    [[ $latest == "$tag" ]] || printf '%-22s %-28s -> %s\n' "$name" "$tag" "$latest"
  done

jq -r '.apps[] | select(.repo | not) | "\(.name) \(.version): pinned by URL, check upstream by hand"' packages.lock.json
