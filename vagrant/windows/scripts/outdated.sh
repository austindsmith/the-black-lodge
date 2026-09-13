#!/usr/bin/env bash
set -euo pipefail

kit_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../kit" && pwd)
cd "$kit_dir"

jq -r '.apps[] | select(.repo) | [.name, .repo, .tag] | @tsv' packages.lock.json |
    while IFS=$'\t' read -r name repo tag; do
        latest=$(gh api "repos/$repo/releases/latest" --jq .tag_name 2>/dev/null || echo '?')
        [[ $latest == "$tag" ]] || printf '%-22s %-28s -> %s\n' "$name" "$tag" "$latest"
    done

jq -r '.apps[] | select(.repo | not) | "\(.name) \(.version): pinned by url, check upstream by hand"' packages.lock.json
