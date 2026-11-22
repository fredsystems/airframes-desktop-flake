#!/usr/bin/env bash
# Point sources.json at an airframesio/assets desktop release.
#
# Usage: scripts/update.sh [desktop-vX.Y.Z]
#
# Without an argument, picks the newest non-draft, non-prerelease
# `desktop-v*` release. Hashes come from the sha256 digests GitHub publishes
# for each release asset, so nothing is downloaded. Prints the new version on
# stdout when sources.json changed, and nothing when it was already current.
#
# Set GITHUB_TOKEN to avoid the unauthenticated API rate limit.

set -euo pipefail

repo="airframesio/assets"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sources="$root/sources.json"

api() {
  local auth=()
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
  fi
  curl -fsSL "${auth[@]}" -H "Accept: application/vnd.github+json" "https://api.github.com/$1"
}

if [[ $# -ge 1 ]]; then
  tag="$1"
  release="$(api "repos/$repo/releases/tags/$tag")"
else
  release="$(api "repos/$repo/releases?per_page=50" |
    jq -e '[.[] | select(.draft == false and .prerelease == false and (.tag_name | startswith("desktop-v")))]
           | sort_by(.published_at) | last')"
  tag="$(jq -r .tag_name <<<"$release")"
fi

if [[ ! "$tag" =~ ^desktop-v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
  echo "unexpected tag format: $tag" >&2
  exit 1
fi
version="${BASH_REMATCH[1]}"

# asset <file name> -> {"url": ..., "hash": "sha256-..."}
asset() {
  local name="$1" json digest
  json="$(jq -e --arg n "$name" '.assets[] | select(.name == $n)' <<<"$release")" || {
    echo "release $tag has no asset named $name" >&2
    exit 1
  }
  digest="$(jq -r .digest <<<"$json")"
  if [[ "$digest" != sha256:* ]]; then
    echo "asset $name has no sha256 digest (got '$digest')" >&2
    exit 1
  fi
  jq -n \
    --arg url "$(jq -r .browser_download_url <<<"$json")" \
    --arg hash "$(nix hash convert --hash-algo sha256 --to sri "${digest#sha256:}")" \
    '{url: $url, hash: $hash}'
}

new="$(jq -n \
  --arg version "$version" \
  --arg tag "$tag" \
  --argjson linux "$(asset "Airframes_${version}_amd64.deb")" \
  --argjson darwin "$(asset "Airframes_universal.app.tar.gz")" \
  '{version: $version, tag: $tag, sources: {"x86_64-linux": $linux, darwin: $darwin}}')"

if [[ "$new" == "$(jq . "$sources")" ]]; then
  exit 0
fi

printf '%s\n' "$new" >"$sources"
echo "$version"
