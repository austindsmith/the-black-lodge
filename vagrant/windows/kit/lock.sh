#!/usr/bin/env bash
# Resolves the kit's inputs into pinned, hash-verified lock files (run on the host):
#   packages.json          -> packages.lock.json       exact URL + sha256 per app
#   python/requirements.in -> python/requirements.txt  resolved for Windows, hashed
#   node/package.json      -> node/package-lock.json
# Pass --upgrade to also move Python/npm dependencies to their newest allowed versions.
# App versions only change when you edit packages.json (see outdated.sh).
set -euo pipefail
cd "$(dirname "$0")"

upgrade=false
[[ ${1:-} == --upgrade ]] && upgrade=true

die() { echo "lock: $*" >&2; exit 1; }

# Fills in {version}/{tag} placeholders and defaults for one app.
render='
  def fill($v; $t): gsub("\\{version\\}"; $v) | gsub("\\{tag\\}"; $t);
  .version as $v
  | ((.tag // "v{version}") | gsub("\\{version\\}"; $v)) as $t
  | (if has("repo") then .tag = $t else . end)
  | with_entries(if (.key | IN("asset", "url", "extract_dir")) then .value |= fill($v; $t) else . end)
  | .path //= ["."]
  | .bin //= []'

echo "==> apps"
jq -c ".apps[] | $render" packages.json | while IFS= read -r app; do
  name=$(jq -r .name <<<"$app")
  if jq -e 'has("repo")' <<<"$app" >/dev/null; then
    repo=$(jq -r .repo <<<"$app")
    tag=$(jq -r .tag <<<"$app")
    asset=$(jq -r .asset <<<"$app")
    url='' digest=''
    read -r url digest < <(gh api "repos/$repo/releases/tags/$tag" </dev/null \
      --jq ".assets[] | select(.name == \"$asset\") | \"\(.browser_download_url) \(.digest // \"\")\"") || true
    [[ -n $url ]] || die "$name: no asset '$asset' in $repo release $tag"
    sha=${digest#sha256:}
    if [[ -z $sha ]]; then
      # Releases published before GitHub started recording asset digests.
      echo "  $name: no published digest, hashing the download" >&2
      sha=$(curl -fsSL "$url" | sha256sum | cut -d' ' -f1)
    fi
    echo "  $name $tag" >&2
    jq --arg url "$url" --arg sha "$sha" '. + {url: $url, sha256: $sha}' <<<"$app"
  else
    jq -e 'has("url") and has("sha256")' <<<"$app" >/dev/null ||
      die "$name: needs either repo + asset, or url + sha256"
    echo "  $name $(jq -r .version <<<"$app") (pinned url)" >&2
    echo "$app"
  fi
done | jq -s '{apps: .}' > packages.lock.json.tmp
mv packages.lock.json.tmp packages.lock.json

echo "==> python"
pyver=$(jq -r '.apps[] | select(.name == "python") | .version' packages.json | cut -d. -f1,2)
uv_args=(--python-platform x86_64-pc-windows-msvc --python-version "$pyver" --generate-hashes --quiet)
$upgrade && uv_args+=(--upgrade)
uv pip compile python/requirements.in --output-file python/requirements.txt "${uv_args[@]}"

if [[ -f node/package.json ]]; then
  echo "==> node"
  npm_args=(--package-lock-only --ignore-scripts --no-audit --no-fund)
  if $upgrade; then (cd node && npm update "${npm_args[@]}"); else (cd node && npm install "${npm_args[@]}"); fi
fi

echo "Review with 'git diff', commit, then 'just build'."
