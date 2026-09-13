#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
kit_dir=$(cd "$script_dir/../kit" && pwd)
cd "$kit_dir"

upgrade=false
[[ ${1:-} == --upgrade ]] && upgrade=true

die() {
    echo "lock: $*" >&2
    exit 1
}

resolve_app() {
    local app=$1
    local name repo tag asset url digest sha

    name=$(jq -r .name <<<"$app")

    if ! jq -e 'has("repo")' <<<"$app" >/dev/null; then
        jq -e 'has("url") and has("sha256")' <<<"$app" >/dev/null ||
            die "$name: needs either repo + asset, or url + sha256"
        echo "  $name $(jq -r .version <<<"$app") (pinned url)" >&2
        echo "$app"
        return
    fi

    repo=$(jq -r .repo <<<"$app")
    tag=$(jq -r .tag <<<"$app")
    asset=$(jq -r .asset <<<"$app")
    url='' digest=''
    read -r url digest < <(gh api "repos/$repo/releases/tags/$tag" </dev/null \
        --jq ".assets[] | select(.name == \"$asset\") | \"\(.browser_download_url) \(.digest // \"\")\"") || true
    [[ -n $url ]] || die "$name: no asset '$asset' in $repo release $tag"

    sha=${digest#sha256:}
    if [[ -z $sha ]]; then
        echo "  $name: release predates GitHub asset digests, hashing the download" >&2
        sha=$(curl -fsSL "$url" | sha256sum | cut -d' ' -f1)
    fi

    echo "  $name $tag" >&2
    jq --arg url "$url" --arg sha "$sha" '. + {url: $url, sha256: $sha}' <<<"$app"
}

lock_apps() {
    local app
    while IFS= read -r app; do
        resolve_app "$app"
    done < <(jq -c -f "$script_dir/render-apps.jq" packages.json) |
        jq -s '{schema: 1, apps: .}' >packages.lock.json.tmp
    mv packages.lock.json.tmp packages.lock.json
}

lock_python() {
    local python_version args
    python_version=$(jq -r '.apps[] | select(.name == "python") | .version' packages.json | cut -d. -f1,2)
    args=(--python-platform x86_64-pc-windows-msvc --python-version "$python_version" --generate-hashes --quiet)
    $upgrade && args+=(--upgrade)
    uv pip compile python/requirements.in --output-file python/requirements.txt "${args[@]}"
}

lock_node() {
    [[ -f node/package.json ]] || return 0
    local args=(--package-lock-only --ignore-scripts --no-audit --no-fund)
    if $upgrade; then
        (cd node && npm update "${args[@]}")
    else
        (cd node && npm install "${args[@]}")
    fi
}

echo "==> apps"
lock_apps
echo "==> python"
lock_python
echo "==> node"
lock_node
echo "Locked. Review with 'git diff', commit, then run 'just build'."
