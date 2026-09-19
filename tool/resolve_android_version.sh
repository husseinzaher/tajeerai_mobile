#!/usr/bin/env bash
# Resolves Android versionName and versionCode for Play Store builds.
#
# Sources:
#   auto    Latest semver git tag, or pubspec.yaml when no tag exists (default)
#   pubspec The version line in pubspec.yaml
#   next    Next releasable semver for the current commit: starts from pubspec,
#           reuses a tag already on HEAD, otherwise bumps patch until a tag is
#           free to create
#
# versionCode is encoded deterministically from semver:
#
#     versionCode = major * 1_000_000 + minor * 1_000 + patch
#
# Examples: v1.0.0 -> 1000000, v1.2.3 -> 1002003, v2.0.0 -> 2000000.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-}"
SOURCE="${2:-auto}"

read_pubspec_version() {
  sed -n 's/^version:[[:space:]]*//p' "$ROOT/pubspec.yaml" | head -1
}

parse_semver() {
  local input="$1"
  IFS=. read -r MAJOR MINOR PATCH _ <<< "${input}.0.0.0"
  MAJOR="${MAJOR:-0}"
  MINOR="${MINOR:-0}"
  PATCH="${PATCH:-0}"

  if ! [[ "$MAJOR" =~ ^[0-9]+$ && "$MINOR" =~ ^[0-9]+$ && "$PATCH" =~ ^[0-9]+$ ]]; then
    echo "Could not parse semver from version '$input' (expected MAJOR.MINOR.PATCH)." >&2
    exit 1
  fi

  if (( MAJOR > 999 || MINOR > 999 || PATCH > 999 )); then
    echo "Version components must be 0..999 for Play Store versionCode encoding: $input" >&2
    exit 1
  fi
}

bump_patch_version() {
  local major minor patch
  IFS=. read -r major minor patch <<< "$1"
  patch=$((patch + 1))

  if (( patch > 999 )); then
    echo "Patch version cannot exceed 999 for $1." >&2
    exit 1
  fi

  printf '%s.%s.%s\n' "$major" "$minor" "$patch"
}

resolve_next_release_version() {
  local head_sha tag_sha version tag

  head_sha="$(git -C "$ROOT" rev-parse HEAD)"
  version="$(read_pubspec_version)"
  version="${version%%+*}"

  while true; do
    tag="v${version}"

    if ! git -C "$ROOT" rev-parse "$tag" >/dev/null 2>&1; then
      printf '%s\n' "$version"
      return
    fi

    tag_sha="$(git -C "$ROOT" rev-parse "$tag^{commit}")"
    if [[ "$tag_sha" == "$head_sha" ]]; then
      printf '%s\n' "$version"
      return
    fi

    version="$(bump_patch_version "$version")"
  done
}

TAG="$(
  git -C "$ROOT" describe --tags --match 'v[0-9]*.[0-9]*.[0-9]*' --abbrev=0 2>/dev/null || true
)"

if [[ "$SOURCE" == "next" ]]; then
  VERSION="$(resolve_next_release_version)"
elif [[ "$SOURCE" == "pubspec" ]]; then
  VERSION="$(read_pubspec_version)"
  VERSION="${VERSION%%+*}"
elif [[ -n "$TAG" ]]; then
  VERSION="${TAG#v}"
else
  VERSION="$(read_pubspec_version)"
  VERSION="${VERSION%%+*}"
fi

parse_semver "$VERSION"
VERSION_CODE=$(( MAJOR * 1000000 + MINOR * 1000 + PATCH ))

case "$MODE" in
  name) echo "$MAJOR.$MINOR.$PATCH" ;;
  number) echo "$VERSION_CODE" ;;
  *)
    echo "BUILD_NAME=$MAJOR.$MINOR.$PATCH"
    echo "BUILD_NUMBER=$VERSION_CODE"
    ;;
esac
