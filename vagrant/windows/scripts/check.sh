#!/usr/bin/env bash
set -uo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root_dir=$(cd "$script_dir/.." && pwd)
cd "$root_dir"

status=0

pass() { printf '  %-22s ok\n' "$1"; }

fail() {
    status=1
    printf '  %-22s FAIL\n' "$1"
    while IFS= read -r line; do
        [[ -n $line ]] && printf '    %s\n' "$line"
    done <<<"$2"
}

check_json_syntax() {
    local errors
    errors=$(for file in kit/packages.json kit/packages.lock.json kit/node/package.json; do
        jq empty "$file" 2>&1 || echo "$file is not valid json"
    done)
    [[ -z $errors ]] && pass json || fail json "$errors"
}

check_manifest() {
    local errors
    errors=$(jq -r '
        def problems($a):
            [ if ($a.name // "") == "" then "app without a name" else empty end,
              if ($a.version // "") == "" then "\($a.name): missing version" else empty end,
              if ($a | has("repo"))
                then (if ($a.asset // "") == "" then "\($a.name): repo without asset" else empty end)
                else (if ($a.url // "") == "" or ($a.sha256 // "") == ""
                      then "\($a.name): needs repo + asset, or url + sha256" else empty end)
              end,
              if (($a.asset // $a.url // "") | test("\\.(exe|gz)$"))
                 and ((($a.asset // $a.url // "") | test("\\.(7z\\.exe|tar\\.gz)$")) | not)
                 and (($a.rename // "") == "")
                then "\($a.name): single-file download needs \"rename\"" else empty end ];
        [ (.apps[] | problems(.)),
          ([.apps[].name] | group_by(.) | map(select(length > 1) | "duplicate app: \(.[0])")),
          (["git", "neovim", "python"] - [.apps[].name] | map("missing required app: \(.)")),
          (if .schema == 1 then [] else ["packages.json: unsupported schema \(.schema // "(unset)")"] end)
        ] | flatten | .[]' kit/packages.json 2>&1)
    [[ -z $errors ]] && pass manifest || fail manifest "$errors"
}

check_lock_in_sync() {
    local strip rendered locked
    strip='if has("repo") then del(.url, .sha256) else . end'
    rendered=$(jq -c -f "$script_dir/render-apps.jq" kit/packages.json | jq -c "$strip" | jq -sS .)
    locked=$(jq -c '.apps[]' kit/packages.lock.json | jq -c "$strip" | jq -sS .)
    if [[ $rendered == "$locked" ]]; then
        pass lock-in-sync
    else
        fail lock-in-sync "packages.lock.json does not match packages.json; run 'just lock'"
    fi
}

normalize_package_names() { tr '[:upper:]_' '[:lower:]-' | sort -u; }

check_python_tools_declared() {
    local missing
    missing=$(comm -23 \
        <(jq -r '.python.tools[]' kit/packages.json | normalize_package_names) \
        <(grep -v '^[[:space:]]*\(#\|$\)' kit/python/requirements.in |
            sed 's/[<>=!~[].*//; s/[[:space:]]*$//' | normalize_package_names))
    [[ -z $missing ]] && pass python-tools ||
        fail python-tools "$(sed 's/^/not in requirements.in: /' <<<"$missing")"
}

check_shell_scripts() {
    local errors
    errors=$(for file in scripts/*.sh; do bash -n "$file" 2>&1; done)
    if command -v shellcheck >/dev/null; then
        errors+=$(shellcheck --severity=warning scripts/*.sh 2>&1)
    fi
    [[ -z $errors ]] && pass shell || fail shell "$errors"
}

check_powershell_is_ascii() {
    local offenders
    offenders=$(grep -rlP '[^\x00-\x7F]' --include='*.ps1' --include='*.psm1' . || true)
    [[ -z $offenders ]] && pass powershell-ascii ||
        fail powershell-ascii "$(sed 's/^/non-ascii (5.1 reads these as ansi): /' <<<"$offenders")"
}

check_vagrantfile() {
    local output
    if ! command -v vagrant >/dev/null; then
        printf '  %-22s skipped (vagrant not installed)\n' vagrantfile
        return
    fi
    output=$(vagrant validate 2>&1) && pass vagrantfile || fail vagrantfile "$output"
}

echo "==> checks"
check_json_syntax
check_manifest
check_lock_in_sync
check_python_tools_declared
check_shell_scripts
check_powershell_is_ascii
check_vagrantfile
exit $status
