#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/fetch-flclash-release-apk.sh <version> [--force] [--output-dir <dir>]

Examples:
  scripts/fetch-flclash-release-apk.sh 0.9.4
  scripts/fetch-flclash-release-apk.sh v0.9.4 --force

Finds the Android arm64 APK in the FlClash GitHub release (FlClash-<version>-android-arm64.apk,
or FlClash-<version>-android-arm64-v8a.apk on older releases), verifies it against the checksum
file of the same release (FlClash-<version>-SHA256SUMS or SHA256SUMS) and saves it into the
output directory, tmp/ by default. Any other APK in that directory is removed, so the deploy
workflow finds exactly one. --force allows replacing a file of the same name.

Set GITHUB_TOKEN or GH_TOKEN to authenticate GitHub API requests.
USAGE
}

version=""
force=""
out_dir=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --force)
      force="--force"
      ;;
    --output-dir)
      [ $# -ge 2 ] || { usage >&2; exit 2; }
      out_dir="$2"
      shift
      ;;
    -*)
      usage >&2
      exit 2
      ;;
    *)
      [ -z "$version" ] || { usage >&2; exit 2; }
      version="${1#v}"
      ;;
  esac
  shift
done

[ -n "$version" ] || { usage >&2; exit 2; }

repo="chen08209/FlClash"
tag="v${version}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
default_out_dir="${repo_root}/tmp"
out_dir="${out_dir:-$default_out_dir}"
work_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
auth=()
if [ -n "$token" ]; then
  auth=(-H "Authorization: Bearer ${token}")
fi

download() {
  curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
    ${auth[@]+"${auth[@]}"} --output "$2" "$1"
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{ print $1 }'
  else
    echo "Neither sha256sum nor shasum is available" >&2
    exit 1
  fi
}

release_json="${work_dir}/release.json"
echo "Listing assets of ${repo} ${tag}"
curl --fail --silent --show-error --location --retry 3 --retry-all-errors \
  -H 'Accept: application/vnd.github+json' ${auth[@]+"${auth[@]}"} \
  --output "$release_json" "https://api.github.com/repos/${repo}/releases/tags/${tag}" ||
  { echo "Could not read release ${tag} of ${repo}" >&2; exit 1; }

asset_url() {
  jq -r --arg name "$1" '.assets[] | select(.name == $name) | .browser_download_url' "$release_json"
}

asset=""
apk_url=""
for candidate in "FlClash-${version}-android-arm64.apk" "FlClash-${version}-android-arm64-v8a.apk"; do
  apk_url="$(asset_url "$candidate")"
  if [ -n "$apk_url" ]; then
    asset="$candidate"
    break
  fi
done

if [ -z "$asset" ]; then
  echo "No arm64 APK in ${repo} ${tag}. Release assets:" >&2
  jq -r '.assets[].name' "$release_json" | sed 's/^/  /' >&2
  exit 1
fi

target="${out_dir}/${asset}"
if [ -e "$target" ] && [ "$force" != "--force" ]; then
  echo "Refusing to overwrite existing file: $target" >&2
  echo "Pass --force to replace it." >&2
  exit 1
fi

echo "Downloading ${asset}"
download "$apk_url" "${work_dir}/${asset}"

expected_sha=""
checksums=""
for candidate in "FlClash-${version}-SHA256SUMS" "SHA256SUMS"; do
  sums_url="$(asset_url "$candidate")"
  [ -n "$sums_url" ] || continue
  echo "Downloading ${candidate}"
  download "$sums_url" "${work_dir}/${candidate}"
  expected_sha="$(
    awk -v asset="$asset" '{ name = $2; sub(/^\*/, "", name); sub(/^\.\//, "", name) } name == asset { print $1; exit }' \
      "${work_dir}/${candidate}"
  )"
  if [ -n "$expected_sha" ]; then
    checksums="$candidate"
    break
  fi
done

if [ -z "$expected_sha" ]; then
  echo "No checksum for ${asset} in ${repo} ${tag} (looked in FlClash-${version}-SHA256SUMS and SHA256SUMS)" >&2
  exit 1
fi

actual_sha="$(sha256_of "${work_dir}/${asset}")"
if [ "$actual_sha" != "$expected_sha" ]; then
  echo "SHA256 mismatch for ${asset} (checked against ${checksums})" >&2
  echo "expected: ${expected_sha}" >&2
  echo "actual:   ${actual_sha}" >&2
  exit 1
fi
echo "SHA256 of ${asset} matches ${checksums}"

mkdir -p "$out_dir"
find "$out_dir" -maxdepth 1 -type f -name '*.apk' ! -name "$asset" -print -delete |
  sed 's/^/Removed: /'
mv "${work_dir}/${asset}" "$target"

echo "Saved: ${target}"
if [ "$out_dir" = "$default_out_dir" ]; then
  echo
  echo "Review and publish with:"
  echo "  git add -A tmp"
  echo "  git commit -m \"Update from ${tag}\""
  echo "  git push origin main"
fi
