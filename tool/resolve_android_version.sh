#!/usr/bin/env bash
# Resolves Android versionName and versionCode for Play Store builds.
#
# Usage:
#   resolve_android_version.sh name [SEMVER]
#   resolve_android_version.sh number [SEMVER]
#
# When SEMVER is omitted, falls back to the latest release Git tag, then
# pubspec.yaml for local development builds.
#
# versionCode = major * 1_000_000 + minor * 1_000 + patch
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-}"
EXPLICIT_VERSION="${2:-}"

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

latest_release_tag() {
  git -C "$ROOT" tag -l 'v[0-9]*.[0-9]*.[0-9]*' | sort -V | tail -1
}

if [[ -n "$EXPLICIT_VERSION" ]]; then
  VERSION="$EXPLICIT_VERSION"
else
  TAG="$(latest_release_tag)"
  if [[ -n "$TAG" ]]; then
    VERSION="${TAG#v}"
  else
    VERSION="$(read_pubspec_version)"
    VERSION="${VERSION%%+*}"
  fi
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
