#!/usr/bin/env bash
set -euo pipefail

package_name="com.follow.clash"
aapt="${AAPT:-aapt}"

usage() {
  cat <<'USAGE'
Usage:
  scripts/fdroid-apk.sh inbox <dir>
  scripts/fdroid-apk.sh info <apk>
  scripts/fdroid-apk.sh import <apk> <repo-dir> [<expected-version>]
  scripts/fdroid-apk.sh prune <repo-dir> <keep-count>
  scripts/fdroid-apk.sh latest <repo-dir>

Works on FlClash APKs by what aapt reads from them, never by file name.

  inbox   Print the only *.apk in <dir>; fail if there is none or more than one.
  info    Check the APK is com.follow.clash with lib/arm64-v8a/ native code and
          print "<versionCode> <versionName>".
  import  Copy the APK into <repo-dir> as FlClash-<versionName>-android-arm64.apk.
          An APK already there with the same versionCode and the same bytes is
          kept as it is; one with different bytes is an error.
  prune   Keep the <keep-count> APKs in <repo-dir> with the highest versionCode.
  latest  Print the APK in <repo-dir> with the highest versionCode.
USAGE
}

die() {
  echo "$*" >&2
  exit 1
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{ print $1 }'
  else
    die "Neither sha256sum nor shasum is available"
  fi
}

badging_of() {
  local badging status=0
  badging="$("$aapt" dump badging "$1")" || status=$?
  printf '%s\n' "$badging" | grep -q '^package: ' || die "aapt could not read $1 (exit ${status})"
  [ "$status" -eq 0 ] || echo "warning: aapt exited ${status} on $1 after printing its package line" >&2
  printf '%s\n' "$badging"
}

package_field() {
  printf '%s\n' "$1" | sed -n "/^package: /s/.* $2='\([^']*\)'.*/\1/p"
}

version_code_of() {
  local badging code
  badging="$(badging_of "$1")" || exit 1
  code="$(package_field "$badging" versionCode)"
  case "$code" in
    '' | *[!0-9]*) die "Unreadable versionCode '${code}' in $1" ;;
  esac
  printf '%s\n' "$code"
}

apk_info() {
  local apk="$1" badging entries name code version_name
  badging="$(badging_of "$apk")" || exit 1
  name="$(package_field "$badging" name)"
  code="$(package_field "$badging" versionCode)"
  version_name="$(package_field "$badging" versionName)"

  [ "$name" = "$package_name" ] || die "$apk is package '${name}', expected '${package_name}'"
  case "$code" in
    '' | *[!0-9]*) die "Unreadable versionCode '${code}' in $apk" ;;
  esac
  case "$version_name" in
    '' | *[!0-9A-Za-z.+_-]*) die "Unusable versionName '${version_name}' in $apk" ;;
  esac
  entries="$(unzip -Z1 "$apk")" || die "unzip could not list $apk"
  printf '%s\n' "$entries" | grep -q '^lib/arm64-v8a/' || die "$apk has no lib/arm64-v8a/ native code"

  printf '%s %s\n' "$code" "$version_name"
}

list_apks() {
  local dir="$1" apk code
  [ -d "$dir" ] || return 0
  find "$dir" -maxdepth 1 -type f -name '*.apk' -print0 |
    while IFS= read -r -d '' apk; do
      code="$(version_code_of "$apk")" || exit 1
      printf '%s\t%s\n' "$code" "$apk"
    done |
    sort -t $'\t' -k1,1nr
}

cmd_inbox() {
  local dir="$1" found count
  [ -d "$dir" ] || die "No such directory: $dir"
  found="$(find "$dir" -maxdepth 1 -type f -name '*.apk' | sort)"
  count="$(printf '%s' "$found" | grep -c . || true)"
  if [ "$count" -eq 0 ]; then
    die "No APK found in $dir"
  fi
  if [ "$count" -gt 1 ]; then
    echo "Expected exactly one APK in $dir, found ${count}:" >&2
    printf '%s\n' "$found" | sed 's/^/  /' >&2
    exit 1
  fi
  printf '%s\n' "$found"
}

cmd_import() {
  local apk="$1" repo_dir="$2" expected="${3#v}" info code version_name listing target existing existing_code
  info="$(apk_info "$apk")" || exit 1
  code="${info%% *}"
  version_name="${info#* }"

  if [ -n "$expected" ] && [ "$version_name" != "$expected" ]; then
    die "$apk is versionName ${version_name}, expected ${expected}"
  fi

  mkdir -p "$repo_dir"
  listing="$(list_apks "$repo_dir")" || exit 1
  while IFS=$'\t' read -r existing_code existing; do
    [ "$existing_code" = "$code" ] || continue
    if [ "$(sha256_of "$existing")" = "$(sha256_of "$apk")" ]; then
      echo "versionCode ${code} is already in the repo as ${existing}; keeping it"
      return 0
    fi
    die "versionCode ${code} is already in the repo as ${existing} with different content"
  done <<<"$listing"

  target="${repo_dir}/FlClash-${version_name}-android-arm64.apk"
  if [ -e "$target" ]; then
    die "$target already exists with a different versionCode"
  fi

  cp "$apk" "$target"
  echo "Imported ${apk} as ${target} (versionName ${version_name}, versionCode ${code})"
}

cmd_prune() {
  local repo_dir="$1" keep="$2" listing apk
  case "$keep" in
    '' | *[!0-9]*) die "keep-count must be a number, got '${keep}'" ;;
  esac
  listing="$(list_apks "$repo_dir")" || exit 1
  while IFS= read -r apk; do
    [ -n "$apk" ] || continue
    echo "Removing ${apk}"
    rm -f "$apk"
  done < <(printf '%s\n' "$listing" | awk -F '\t' -v keep="$keep" 'NF && NR > keep { print $2 }')
}

cmd_latest() {
  local listing latest
  listing="$(list_apks "$1")" || exit 1
  latest="$(printf '%s\n' "$listing" | awk -F '\t' 'NR == 1 { print $2 }')"
  [ -n "$latest" ] || die "No APK found in $1"
  printf '%s\n' "$latest"
}

case "${1:-}" in
  inbox) [ $# -eq 2 ] || { usage >&2; exit 2; }; cmd_inbox "$2" ;;
  info) [ $# -eq 2 ] || { usage >&2; exit 2; }; apk_info "$2" ;;
  import) { [ $# -eq 3 ] || [ $# -eq 4 ]; } || { usage >&2; exit 2; }; cmd_import "$2" "$3" "${4:-}" ;;
  prune) [ $# -eq 3 ] || { usage >&2; exit 2; }; cmd_prune "$2" "$3" ;;
  latest) [ $# -eq 2 ] || { usage >&2; exit 2; }; cmd_latest "$2" ;;
  -h | --help) usage ;;
  *) usage >&2; exit 2 ;;
esac
