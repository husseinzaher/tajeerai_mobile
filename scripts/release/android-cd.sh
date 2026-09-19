#!/usr/bin/env bash
# Local Android CD pipeline for Tajeer AI mobile.
#
# Reads the release version from pubspec.yaml, ensures a matching annotated Git
# tag exists on the current commit, runs verification, builds a signed App
# Bundle, and validates the artifact. Designed to be invoked by `make cd-local`
# and reusable from future CI without GitHub-specific logic.
#
# Environment overrides:
#   ALLOW_DIRTY=1   Continue with uncommitted changes (default: fail)
#   SKIP_VERIFY=1   Skip `make verify` (default: run verify)
#   DRY_RUN=1       Validate and print planned steps only (no tag/build)
#   PUSH_TAG=1      Push a newly created release tag to origin (default: local only)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AAB_REL="build/app/outputs/bundle/release/app-release.aab"
AAB_PATH="$ROOT/$AAB_REL"
RELEASE_TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+$'

ALLOW_DIRTY="${ALLOW_DIRTY:-0}"
SKIP_VERIFY="${SKIP_VERIFY:-0}"
DRY_RUN="${DRY_RUN:-0}"
PUSH_TAG="${PUSH_TAG:-0}"

TAG_ACTION="NONE"
TAG_STATUS="UNKNOWN"
TAG_PUSHED="no"
VERIFY_STATUS="SKIPPED"
BUILD_STATUS="SKIPPED"
AAB_SIZE=""

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 || fail "Required command not found on PATH: $name"
}

human_size() {
  local bytes="$1"

  if (( bytes >= 1048576 )); then
    awk -v b="$bytes" 'BEGIN { printf "%.1f MB", b / 1048576 }'
  elif (( bytes >= 1024 )); then
    awk -v b="$bytes" 'BEGIN { printf "%.1f KB", b / 1024 }'
  else
    printf '%d B' "$bytes"
  fi
}

validate_commands() {
  require_command git
  require_command flutter
  require_command make
}

validate_clean_worktree() {
  if [[ "$ALLOW_DIRTY" == "1" ]]; then
    log "WARNING: ALLOW_DIRTY=1 — continuing with uncommitted changes."
    return
  fi

  if ! git -C "$ROOT" diff-index --quiet HEAD --; then
    fail "Working tree has uncommitted changes. Commit or stash them, or rerun with ALLOW_DIRTY=1."
  fi

  if [[ -n "$(git -C "$ROOT" ls-files --others --exclude-standard)" ]]; then
    fail "Working tree has untracked files. Add or ignore them, or rerun with ALLOW_DIRTY=1."
  fi
}

read_release_version() {
  VERSION_NAME="$(bash "$ROOT/tool/resolve_android_version.sh" name pubspec)"
  VERSION_CODE="$(bash "$ROOT/tool/resolve_android_version.sh" number pubspec)"
  RELEASE_TAG="v${VERSION_NAME}"

  if [[ -z "$VERSION_NAME" || -z "$VERSION_CODE" ]]; then
    fail "Version resolver returned empty values from pubspec.yaml."
  fi

  if [[ ! "$RELEASE_TAG" =~ $RELEASE_TAG_PATTERN ]]; then
    fail "Release version '$VERSION_NAME' is invalid. Expected MAJOR.MINOR.PATCH in pubspec.yaml."
  fi
}

resolve_version() {
  read_release_version

  local resolved_name resolved_code
  resolved_name="$(bash "$ROOT/tool/resolve_android_version.sh" name pubspec)"
  resolved_code="$(bash "$ROOT/tool/resolve_android_version.sh" number pubspec)"

  if [[ "$resolved_name" != "$VERSION_NAME" || "$resolved_code" != "$VERSION_CODE" ]]; then
    fail "Version resolver mismatch for pubspec release $VERSION_NAME."
  fi
}

inspect_existing_tag() {
  local head_sha tag_sha

  head_sha="$(git -C "$ROOT" rev-parse HEAD)"

  if ! git -C "$ROOT" rev-parse "$RELEASE_TAG" >/dev/null 2>&1; then
    TAG_STATUS="MISSING"
    return 1
  fi

  tag_sha="$(git -C "$ROOT" rev-parse "$RELEASE_TAG^{commit}")"

  if [[ "$tag_sha" == "$head_sha" ]]; then
    TAG_STATUS="EXISTS (HEAD)"
    return 0
  fi

  TAG_STATUS="EXISTS (OTHER COMMIT)"
  fail "Release tag $RELEASE_TAG already exists on commit ${tag_sha:0:7} but HEAD is ${head_sha:0:7}. Bump the version in pubspec.yaml before creating another release."
}

ensure_release_tag() {
  if inspect_existing_tag; then
    TAG_ACTION="REUSED"
    return
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    TAG_ACTION="WOULD CREATE ANNOTATED TAG"
    return
  fi

  git -C "$ROOT" tag -a "$RELEASE_TAG" -m "Release $RELEASE_TAG"
  TAG_ACTION="CREATED"

  if [[ "$PUSH_TAG" == "1" ]]; then
    require_command git
    log "Pushing release tag $RELEASE_TAG to origin..."
    git -C "$ROOT" push origin "$RELEASE_TAG"
    TAG_PUSHED="yes"
  fi
}

run_verify() {
  if [[ "$SKIP_VERIFY" == "1" ]]; then
    VERIFY_STATUS="SKIPPED"
    log "WARNING: SKIP_VERIFY=1 — skipping make verify."
    return
  fi

  log "Running make verify..."
  if make -C "$ROOT" verify; then
    VERIFY_STATUS="PASSED"
  else
    VERIFY_STATUS="FAILED"
    fail "make verify failed."
  fi
}

run_build() {
  log "Running make android-build..."
  if make -C "$ROOT" android-build \
    "ANDROID_BUILD_NAME=$VERSION_NAME" \
    "ANDROID_BUILD_NUMBER=$VERSION_CODE"; then
    BUILD_STATUS="PASSED"
  else
    BUILD_STATUS="FAILED"
    fail "make android-build failed."
  fi
}

verify_artifact() {
  [[ -f "$AAB_PATH" ]] || fail "Expected AAB not found at $AAB_REL."
  [[ -s "$AAB_PATH" ]] || fail "AAB exists but is empty: $AAB_REL."

  AAB_SIZE="$(human_size "$(wc -c < "$AAB_PATH" | tr -d ' ')")"
}

print_dry_run_plan() {
  log ""
  log "Release version: $VERSION_NAME"
  log "Release tag:     $RELEASE_TAG"
  log "Tag status:      $TAG_STATUS"
  if [[ "$TAG_ACTION" == "WOULD CREATE ANNOTATED TAG" ]]; then
    log "Action:          WOULD CREATE ANNOTATED TAG"
  elif [[ "$TAG_ACTION" == "REUSED" ]]; then
    log "Action:          WOULD REUSE EXISTING TAG"
  fi
  if [[ "$SKIP_VERIFY" != "1" ]]; then
    log "Action:          WOULD RUN VERIFY"
  else
    log "Action:          WOULD SKIP VERIFY (SKIP_VERIFY=1)"
  fi
  log "Action:          WOULD BUILD AAB"
}

print_summary() {
  log ""
  log "========================================"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "Local Android CD (dry run)"
  else
    log "Local Android CD"
  fi
  log "========================================"
  log "Version:       $VERSION_NAME"
  log "Version code:  $VERSION_CODE"
  log "Release tag:   $RELEASE_TAG"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "Tag status:    $TAG_STATUS"
    log "Tag action:    $TAG_ACTION"
    log "Verification:  $VERIFY_STATUS"
    log "Build:         $BUILD_STATUS"
  else
    log "Tag action:    $TAG_ACTION"
    log "Verification:  $VERIFY_STATUS"
    log "Build:         $BUILD_STATUS"
    log "Artifact:      $AAB_REL"
    if [[ -n "$AAB_SIZE" ]]; then
      log "Size:          $AAB_SIZE"
    fi
    if [[ "$TAG_ACTION" == "CREATED" ]]; then
      if [[ "$TAG_PUSHED" == "yes" ]]; then
        log "Tag pushed:    yes"
      else
        log "Tag pushed:    no (local only; set PUSH_TAG=1 to push)"
      fi
    fi
  fi
  log "========================================"
}

main() {
  cd "$ROOT"

  validate_commands
  validate_clean_worktree
  resolve_version
  ensure_release_tag

  if [[ "$DRY_RUN" == "1" ]]; then
    if [[ "$SKIP_VERIFY" == "1" ]]; then
      VERIFY_STATUS="SKIPPED"
    else
      VERIFY_STATUS="WOULD RUN"
    fi
    BUILD_STATUS="WOULD RUN"
    print_dry_run_plan
    print_summary
    return
  fi

  run_verify
  run_build
  verify_artifact
  print_summary
}

main "$@"
