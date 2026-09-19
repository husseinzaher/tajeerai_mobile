#!/usr/bin/env bash
# Resolves Android versionName and versionCode for Play Store builds.
#
# Source of truth: the latest semver git tag matching vMAJOR.MINOR.PATCH
# (for example v1.2.3 -> versionName 1.2.3). When no such tag exists, falls
# back to the version line in pubspec.yaml.
#
# versionCode is encoded deterministically from semver so every release tag
# receives a strictly larger integer than any earlier tag with a lower version:
#
#     versionCode = major * 1_000_000 + minor * 1_000 + patch
#
# Examples: v1.0.0 -> 1000000, v1.2.3 -> 1002003, v2.0.0 -> 2000000.
#
# Each component must be 0..999. This matches Google Play's requirement that
# versionCode monotonically increase, without an arbitrary counter that can
# drift from the tag history.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-}"
SOURCE="${2:-auto}"

read_pubspec_version() {
  sed -n 's/^version:[[:space:]]*//p' "$ROOT/pubspec.yaml" | head -1
}

TAG="$(
  git -C "$ROOT" describe --tags --match 'v[0-9]*.[0-9]*.[0-9]*' --abbrev=0 2>/dev/null || true
)"

if [[ "$SOURCE" == "pubspec" ]]; then
  VERSION="$(read_pubspec_version)"
  VERSION="${VERSION%%+*}"
elif [[ -n "$TAG" ]]; then
  VERSION="${TAG#v}"
else
  VERSION="$(read_pubspec_version)"
  VERSION="${VERSION%%+*}"
fi

IFS=. read -r MAJOR MINOR PATCH _ <<< "${VERSION}.0.0.0"
MAJOR="${MAJOR:-0}"
MINOR="${MINOR:-0}"
PATCH="${PATCH:-0}"

if ! [[ "$MAJOR" =~ ^[0-9]+$ && "$MINOR" =~ ^[0-9]+$ && "$PATCH" =~ ^[0-9]+$ ]]; then
  echo "Could not parse semver from version '$VERSION' (expected MAJOR.MINOR.PATCH)." >&2
  exit 1
fi

if (( MAJOR > 999 || MINOR > 999 || PATCH > 999 )); then
  echo "Version components must be 0..999 for Play Store versionCode encoding: $VERSION" >&2
  exit 1
fi

VERSION_CODE=$(( MAJOR * 1000000 + MINOR * 1000 + PATCH ))

case "$MODE" in
  name) echo "$MAJOR.$MINOR.$PATCH" ;;
  number) echo "$VERSION_CODE" ;;
  *)
    echo "BUILD_NAME=$MAJOR.$MINOR.$PATCH"
    echo "BUILD_NUMBER=$VERSION_CODE"
    ;;
esac
