#!/usr/bin/env bash

ACCOUNT_ID=$(echo "$CLOUDFLARE_SECRETS" | yq '.cloudflare_account_id')
ZONE_ID=$(echo "$CLOUDFLARE_SECRETS" | yq ".zones[\"$CLOUDFLARE_DOMAIN\"]")
OUT_DIR="$(pwd)"
TF_PATH="$(which terraform)"
TF_INSTALL_PATH="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_FILE="$SCRIPT_DIR/resources.yaml"

generate() {
  local outfile="$1"
  local flag="$2"
  local id="$3"
  local resource="$4"

  echo "  generating $resource..."
  mkdir -p "$(dirname "$outfile")"

  cf-terraforming generate \
    --terraform-binary-path "$TF_PATH" \
    --terraform-install-path "$TF_INSTALL_PATH" \
    "$flag" "$id" \
    --resource-type "$resource" \
    >"$outfile"
}

process_scope() {
  local scope="$1"
  local flag="$2"
  local id="$3"

  echo "==> $scope-scoped resources"

  while IFS= read -r folder; do
    folder="$(echo "$folder" | tr -d ' ')"
    [[ -z "$folder" ]] && continue

    echo "  --> $scope/$folder"

    while IFS= read -r resource; do
      resource="$(echo "$resource" | tr -d ' ')"
      [[ -z "$resource" ]] && continue

      generate "$OUT_DIR/$scope/$folder/${resource}.tf" "$flag" "$id" "$resource"
    done < <(yq e ".${scope}[\"${folder}\"][] | select(. != null)" "$RESOURCES_FILE" 2>/dev/null)

  done < <(yq e ".${scope} | keys | .[]" "$RESOURCES_FILE" 2>/dev/null)
}

process_scope "account" "--account" "$ACCOUNT_ID"
process_scope "zone" "--zone" "$ZONE_ID"

echo "==> cleaning up empty files"
find "$OUT_DIR/account" "$OUT_DIR/zone" -name "*.tf" -empty -delete 2>/dev/null

echo "==> cleaning up empty directories"
find "$OUT_DIR/account" "$OUT_DIR/zone" -type d -empty -delete 2>/dev/null

echo "done. output in $OUT_DIR"
find "$OUT_DIR" -name "*.tf" | sort
