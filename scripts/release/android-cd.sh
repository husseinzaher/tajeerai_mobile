#!/usr/bin/env bash
# Shared Android CD pipeline for Tajeer AI mobile.
#
# Reads the release version from pubspec.yaml, ensures a matching annotated Git
# tag exists on the current commit, runs verification, builds a signed App
# Bundle, validates the artifact, and optionally uploads to Google Play.
#
# Invoked by:
#   make cd-local          (--mode local)
#   make cd MODE=github    (--mode github)
#
# Environment overrides:
#   ALLOW_DIRTY=1            Continue with uncommitted changes (default: fail)
#   SKIP_VERIFY=1            Skip `make verify` (default: run verify)
#   DRY_RUN=1                Validate and print planned steps only
#   PUSH_TAG=0|1             Push a newly created release tag (mode defaults apply)
#   UPLOAD=0|1               Upload AAB to Google Play (mode defaults apply)
#   GOOGLE_PLAY_TRACK=...    Play track (default: internal)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AAB_REL="build/app/outputs/bundle/release/app-release.aab"
AAB_PATH="$ROOT/$AAB_REL"
PACKAGE_NAME="com.tajeerai.mobile"
RELEASE_TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+$'
PLAY_SERVICE_ACCOUNT_DEFAULT="$ROOT/android/play-service-account.json"

CD_MODE="local"
ALLOW_DIRTY="${ALLOW_DIRTY:-0}"
SKIP_VERIFY="${SKIP_VERIFY:-0}"
DRY_RUN="${DRY_RUN:-0}"
PUSH_TAG=""
UPLOAD=""
GOOGLE_PLAY_TRACK="${GOOGLE_PLAY_TRACK:-internal}"

TAG_ACTION="NONE"
TAG_STATUS="UNKNOWN"
TAG_PUSHED="no"
VERIFY_STATUS="SKIPPED"
BUILD_STATUS="SKIPPED"
AAB_STATUS="SKIPPED"
UPLOAD_STATUS="SKIPPED"
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

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode)
        CD_MODE="${2:-}"
        shift 2
        ;;
      --mode=*)
        CD_MODE="${1#*=}"
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  case "$CD_MODE" in
    local|github) ;;
    *)
      fail "Unknown CD mode '$CD_MODE'. Expected --mode local or --mode github."
      ;;
  esac
}

apply_mode_defaults() {
  if [[ -z "$PUSH_TAG" ]]; then
    if [[ "$CD_MODE" == "github" ]]; then
      PUSH_TAG=1
    else
      PUSH_TAG=0
    fi
  fi

  if [[ -z "$UPLOAD" ]]; then
    if [[ "$CD_MODE" == "github" ]]; then
      UPLOAD=1
    else
      UPLOAD=0
    fi
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

configure_git_identity_for_tagging() {
  if [[ "$CD_MODE" == "github" ]]; then
    git -C "$ROOT" config user.email "github-actions[bot]@users.noreply.github.com"
    git -C "$ROOT" config user.name "github-actions[bot]"
  fi
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

  configure_git_identity_for_tagging
  git -C "$ROOT" tag -a "$RELEASE_TAG" -m "Release $RELEASE_TAG"
  TAG_ACTION="CREATED"

  if [[ "$PUSH_TAG" == "1" ]]; then
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
  if [[ ! -f "$AAB_PATH" ]]; then
    AAB_STATUS="FAILED"
    fail "Expected AAB not found at $AAB_REL."
  fi

  if [[ ! -s "$AAB_PATH" ]]; then
    AAB_STATUS="FAILED"
    fail "AAB exists but is empty: $AAB_REL."
  fi

  AAB_SIZE="$(human_size "$(wc -c < "$AAB_PATH" | tr -d ' ')")"
  AAB_STATUS="PASSED"
}

play_service_account_path() {
  if [[ -n "${GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:-}" && -f "$GOOGLE_PLAY_SERVICE_ACCOUNT_JSON" ]]; then
    printf '%s\n' "$GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"
    return 0
  fi

  if [[ -f "$PLAY_SERVICE_ACCOUNT_DEFAULT" ]]; then
    printf '%s\n' "$PLAY_SERVICE_ACCOUNT_DEFAULT"
    return 0
  fi

  return 1
}

play_upload_configured() {
  play_service_account_path >/dev/null
}

upload_to_play() {
  if [[ "$UPLOAD" != "1" ]]; then
    UPLOAD_STATUS="SKIPPED"
    return
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    UPLOAD_STATUS="WOULD RUN"
    return
  fi

  local service_account
  if ! service_account="$(play_service_account_path)"; then
    UPLOAD_STATUS="FAILED"
    fail "Google Play upload is not configured. Set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON to a service-account JSON file path, or place the file at android/play-service-account.json (gitignored)."
  fi

  require_command fastlane

  log "Uploading AAB to Google Play (track: $GOOGLE_PLAY_TRACK)..."
  if fastlane supply \
    --aab "$AAB_PATH" \
    --package_name "$PACKAGE_NAME" \
    --track "$GOOGLE_PLAY_TRACK" \
    --json_key "$service_account" \
    --skip_upload_apk \
    --skip_upload_metadata \
    --skip_upload_images \
    --skip_upload_screenshots; then
    UPLOAD_STATUS="PASSED"
  else
    UPLOAD_STATUS="FAILED"
    fail "Google Play upload failed."
  fi
}

print_dry_run_plan() {
  log ""
  log "Release version: $VERSION_NAME"
  log "Release tag:     $RELEASE_TAG"
  log "Tag status:      $TAG_STATUS"
  if [[ "$TAG_ACTION" == "WOULD CREATE ANNOTATED TAG" ]]; then
    log "Action:          WOULD CREATE ANNOTATED TAG"
    if [[ "$PUSH_TAG" == "1" ]]; then
      log "Action:          WOULD PUSH TAG TO ORIGIN"
    fi
  elif [[ "$TAG_ACTION" == "REUSED" ]]; then
    log "Action:          WOULD REUSE EXISTING TAG"
  fi
  if [[ "$SKIP_VERIFY" != "1" ]]; then
    log "Action:          WOULD RUN VERIFY"
  else
    log "Action:          WOULD SKIP VERIFY (SKIP_VERIFY=1)"
  fi
  log "Action:          WOULD BUILD AAB"
  log "Action:          WOULD VALIDATE AAB"
  if [[ "$UPLOAD" == "1" ]]; then
    if play_upload_configured; then
      log "Action:          WOULD UPLOAD TO GOOGLE PLAY ($GOOGLE_PLAY_TRACK)"
    else
      log "Action:          WOULD UPLOAD TO GOOGLE PLAY (credentials missing — would fail)"
    fi
  fi
}

print_summary() {
  log ""
  log "========================================"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "Android Release (dry run)"
  else
    log "Android Release"
  fi
  log "========================================"
  log "Mode:          $CD_MODE"
  log "Tag:           $RELEASE_TAG"
  log "Version:       $VERSION_NAME"
  log "Version code:  $VERSION_CODE"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "Tag status:    $TAG_STATUS"
    log "Tag action:    $TAG_ACTION"
    log "Verification:  $VERIFY_STATUS"
    log "Build:         $BUILD_STATUS"
    log "AAB:           $([ "$BUILD_STATUS" == "WOULD RUN" ] && echo WOULD RUN || echo SKIPPED)"
    if [[ "$UPLOAD" == "1" ]]; then
      log "Track:         $GOOGLE_PLAY_TRACK"
      log "Upload:        $UPLOAD_STATUS"
    else
      log "Upload:        SKIPPED"
    fi
  else
    log "Tag action:    $TAG_ACTION"
    log "Verification:  $VERIFY_STATUS"
    log "Build:         $BUILD_STATUS"
    log "AAB:           $AAB_STATUS"
    log "Artifact:      $AAB_REL"
    if [[ -n "$AAB_SIZE" ]]; then
      log "Size:          $AAB_SIZE"
    fi
    if [[ "$TAG_ACTION" == "CREATED" ]]; then
      if [[ "$TAG_PUSHED" == "yes" ]]; then
        log "Tag pushed:    yes"
      else
        log "Tag pushed:    no (local only; GitHub mode sets PUSH_TAG=1)"
      fi
    fi
    if [[ "$UPLOAD" == "1" ]]; then
      log "Track:         $GOOGLE_PLAY_TRACK"
      log "Upload:        $UPLOAD_STATUS"
    else
      log "Upload:        SKIPPED"
    fi
  fi
  log "========================================"
}

main() {
  parse_args "$@"
  apply_mode_defaults

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
    if [[ "$UPLOAD" == "1" ]]; then
      if play_upload_configured; then
        UPLOAD_STATUS="WOULD RUN"
      else
        UPLOAD_STATUS="WOULD FAIL (missing credentials)"
      fi
    else
      UPLOAD_STATUS="SKIPPED"
    fi
    print_dry_run_plan
    print_summary
    return
  fi

  run_verify
  run_build
  verify_artifact
  upload_to_play
  print_summary
}

main "$@"
