#!/usr/bin/env bash
# Calculates the next Android release version from Git tags and Conventional
# Commits. Non-conventional commit subjects are treated as patch bumps so
# legacy history does not block the release pipeline.
#
# Usage:
#   resolve_release_version.sh name
#   resolve_release_version.sh number
#   resolve_release_version.sh tag
#   resolve_release_version.sh type
#   resolve_release_version.sh latest-tag
#   resolve_release_version.sh commits
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-}"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

read_pubspec_version() {
  local version
  version="$(sed -n 's/^version:[[:space:]]*//p' "$ROOT/pubspec.yaml" | head -1)"
  version="${version%%+*}"
  printf '%s\n' "$version"
}

latest_release_tag() {
  git -C "$ROOT" tag -l 'v[0-9]*.[0-9]*.[0-9]*' | sort -V | tail -1
}

parse_semver() {
  local input="$1"
  IFS=. read -r RELEASE_MAJOR RELEASE_MINOR RELEASE_PATCH _ <<< "${input}.0.0.0"
  RELEASE_MAJOR="${RELEASE_MAJOR:-0}"
  RELEASE_MINOR="${RELEASE_MINOR:-0}"
  RELEASE_PATCH="${RELEASE_PATCH:-0}"

  if ! [[ "$RELEASE_MAJOR" =~ ^[0-9]+$ && "$RELEASE_MINOR" =~ ^[0-9]+$ && "$RELEASE_PATCH" =~ ^[0-9]+$ ]]; then
    fail "Could not parse semver from version '$input' (expected MAJOR.MINOR.PATCH)."
  fi

  if (( RELEASE_MAJOR > 999 || RELEASE_MINOR > 999 || RELEASE_PATCH > 999 )); then
    fail "Version components must be 0..999: $input"
  fi
}

bump_semver() {
  local level="$1"

  case "$level" in
    major)
      RELEASE_MAJOR=$((RELEASE_MAJOR + 1))
      RELEASE_MINOR=0
      RELEASE_PATCH=0
      ;;
    minor)
      RELEASE_MINOR=$((RELEASE_MINOR + 1))
      RELEASE_PATCH=0
      ;;
    patch)
      RELEASE_PATCH=$((RELEASE_PATCH + 1))
      ;;
    none) ;;
    *)
      fail "Unknown bump level: $level"
      ;;
  esac
}

commit_bump_level() {
  local subject="$1"
  local body="$2"
  local type_part commit_type

  if [[ "$body" == *"BREAKING CHANGE:"* || "$body" == *"BREAKING-CHANGE:"* ]]; then
    printf 'major\n'
    return
  fi

  if [[ "$subject" != *:* ]]; then
    printf 'patch\n'
    return
  fi

  type_part="${subject%%:*}"

  if [[ "$type_part" == *"!"* ]]; then
    printf 'major\n'
    return
  fi

  if [[ "$type_part" == *"("* ]]; then
    commit_type="${type_part%%(*}"
  else
    commit_type="$type_part"
  fi

  case "$commit_type" in
    feat) printf 'minor\n' ;;
    fix|perf|refactor|docs|chore|test|build|ci) printf 'patch\n' ;;
    *) printf 'patch\n' ;;
  esac
}

warn_non_conventional_commit() {
  local subject="$1"
  printf 'WARN: Treating non-conventional commit as patch bump: %s\n' "$subject" >&2
}

is_conventional_commit() {
  local subject="$1"
  local body="$2"
  local type_part commit_type

  if [[ "$body" == *"BREAKING CHANGE:"* || "$body" == *"BREAKING-CHANGE:"* ]]; then
    return 0
  fi

  if [[ "$subject" != *:* ]]; then
    return 1
  fi

  type_part="${subject%%:*}"

  if [[ "$type_part" == *"!"* ]]; then
    return 0
  fi

  if [[ "$type_part" == *"("* ]]; then
    commit_type="${type_part%%(*}"
  else
    commit_type="$type_part"
  fi

  case "$commit_type" in
    feat|fix|perf|refactor|docs|chore|test|build|ci) return 0 ;;
    *) return 1 ;;
  esac
}

merge_bump_levels() {
  local current="$1"
  local incoming="$2"

  if [[ "$incoming" == "major" || "$current" == "major" ]]; then
    printf 'major\n'
  elif [[ "$incoming" == "minor" || "$current" == "minor" ]]; then
    printf 'minor\n'
  elif [[ "$incoming" == "patch" || "$current" == "patch" ]]; then
    printf 'patch\n'
  else
    printf 'none\n'
  fi
}

LATEST_TAG=""
COMMITS_COUNT=0
RELEASE_TYPE="NONE"
BASE_VERSION=""
NEXT_VERSION=""

resolve_release() {
  local latest_tag base_version bump_level subject body
  local -a subjects=()
  local -a bodies=()

  LATEST_TAG="$(latest_release_tag)"

  if [[ -z "$LATEST_TAG" ]]; then
    BASE_VERSION="$(read_pubspec_version)"
    parse_semver "$BASE_VERSION"
    NEXT_VERSION="${RELEASE_MAJOR}.${RELEASE_MINOR}.${RELEASE_PATCH}"
    RELEASE_TYPE="INITIAL"
    COMMITS_COUNT=0
    return
  fi

  BASE_VERSION="${LATEST_TAG#v}"
  parse_semver "$BASE_VERSION"

  mapfile -t subjects < <(git -C "$ROOT" log "${LATEST_TAG}..HEAD" --no-merges --format=%s)
  mapfile -t bodies < <(git -C "$ROOT" log "${LATEST_TAG}..HEAD" --no-merges --format=%B)

  COMMITS_COUNT="${#subjects[@]}"
  bump_level="none"

  if (( COMMITS_COUNT == 0 )); then
    NEXT_VERSION="${RELEASE_MAJOR}.${RELEASE_MINOR}.${RELEASE_PATCH}"
    RELEASE_TYPE="REUSE"
    return
  fi

  local index=0
  for subject in "${subjects[@]}"; do
    body="${bodies[$index]:-}"
    index=$((index + 1))

    if ! is_conventional_commit "$subject" "$body"; then
      warn_non_conventional_commit "$subject"
    fi

    local level
    level="$(commit_bump_level "$subject" "$body")"
    bump_level="$(merge_bump_levels "$bump_level" "$level")"
  done

  bump_semver "$bump_level"
  NEXT_VERSION="${RELEASE_MAJOR}.${RELEASE_MINOR}.${RELEASE_PATCH}"

  case "$bump_level" in
    major) RELEASE_TYPE="MAJOR" ;;
    minor) RELEASE_TYPE="MINOR" ;;
    patch) RELEASE_TYPE="PATCH" ;;
    none) RELEASE_TYPE="REUSE" ;;
  esac
}

resolve_release

case "$MODE" in
  name) printf '%s\n' "$NEXT_VERSION" ;;
  number) bash "$ROOT/tool/resolve_android_version.sh" number "$NEXT_VERSION" ;;
  tag) printf 'v%s\n' "$NEXT_VERSION" ;;
  type) printf '%s\n' "$RELEASE_TYPE" ;;
  latest-tag) printf '%s\n' "${LATEST_TAG:-none}" ;;
  commits) printf '%s\n' "$COMMITS_COUNT" ;;
  *)
    fail "Unknown mode '$MODE'. Expected name, number, tag, type, latest-tag, or commits."
    ;;
esac
