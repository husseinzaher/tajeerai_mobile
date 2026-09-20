#!/usr/bin/env bash
# Shared Android CD pipeline for Tajeer AI mobile.
#
# Release versions come from Git tags + Conventional Commits. pubspec.yaml is
# not modified; Flutter receives --build-name and --build-number at build time.
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
#   UPLOAD=0|1               Upload AAB to Google Play (default: 1 for local and github)
#   GOOGLE_PLAY_TRACK=...    Play track (default: internal)
#
# Local release flow (make cd-local):
#   version validation → make verify → make android-build → AAB check → Play upload
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

LATEST_TAG="none"
COMMITS_COUNT=0
RELEASE_TYPE="NONE"
VERSION_NAME=""
VERSION_CODE=""
RELEASE_TAG=""
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

fail_after_tag() {
  printf 'ERROR: %s\n' "$*" >&2
  if [[ "$TAG_ACTION" == "CREATED" ]]; then
    log ""
    log "Release tag $RELEASE_TAG was already created locally and was NOT deleted."
    log "Do not move or overwrite it. Fix the failure, then rerun the release."
  fi
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
    UPLOAD=1
  fi
}

validate_commands() {
  require_command git
  require_command flutter
  require_command make
}

validate_clean_worktree() {
  if [[ "$ALLOW_DIRTY" == "1" ]]; then
    log "WARNING: ALLOW_DIRTY=1 — uncommitted changes are NOT included in the Git tag."
    return
  fi

  if ! git -C "$ROOT" diff-index --quiet HEAD --; then
    fail "Working tree has uncommitted changes. Commit or stash them, or rerun with ALLOW_DIRTY=1."
  fi

  if [[ -n "$(git -C "$ROOT" ls-files --others --exclude-standard)" ]]; then
    fail "Working tree has untracked files. Add or ignore them, or rerun with ALLOW_DIRTY=1."
  fi
}

resolve_release_version() {
  LATEST_TAG="$(bash "$ROOT/tool/resolve_release_version.sh" latest-tag)"
  COMMITS_COUNT="$(bash "$ROOT/tool/resolve_release_version.sh" commits)"
  RELEASE_TYPE="$(bash "$ROOT/tool/resolve_release_version.sh" type)"
  VERSION_NAME="$(bash "$ROOT/tool/resolve_release_version.sh" name)"
  VERSION_CODE="$(bash "$ROOT/tool/resolve_release_version.sh" number)"
  RELEASE_TAG="$(bash "$ROOT/tool/resolve_release_version.sh" tag)"

  if [[ -z "$VERSION_NAME" || -z "$VERSION_CODE" || -z "$RELEASE_TAG" ]]; then
    fail "Release version resolver returned empty values."
  fi

  if [[ ! "$RELEASE_TAG" =~ $RELEASE_TAG_PATTERN ]]; then
    fail "Release tag '$RELEASE_TAG' is invalid. Expected format: vMAJOR.MINOR.PATCH."
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
  fail "Release tag $RELEASE_TAG already exists on commit ${tag_sha:0:7} but HEAD is ${head_sha:0:7}. Resolve the conflict manually; existing tags are never moved or overwritten."
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
    TAG_ACTION="WOULD CREATE ${RELEASE_TAG}"
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
    fail_after_tag "make verify failed."
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
    fail_after_tag "make android-build failed."
  fi
}

verify_artifact() {
  if [[ ! -f "$AAB_PATH" ]]; then
    AAB_STATUS="FAILED"
    fail_after_tag "Expected AAB not found at $AAB_REL."
  fi

  if [[ ! -s "$AAB_PATH" ]]; then
    AAB_STATUS="FAILED"
    fail_after_tag "AAB exists but is empty: $AAB_REL."
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

validate_upload_prerequisites() {
  if [[ "$UPLOAD" != "1" || "$DRY_RUN" == "1" ]]; then
    return
  fi

  require_command fastlane

  if ! play_upload_configured; then
    fail "Google Play upload is required for this release but credentials are missing. Set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON to a service-account JSON file path, or place the file at android/play-service-account.json (gitignored)."
  fi
}

upload_to_play() {
  if [[ "$UPLOAD" != "1" ]]; then
    UPLOAD_STATUS="SKIPPED"
    return
  fi

  local service_account
  service_account="$(play_service_account_path)"

  log "Uploading AAB to Google Play (track: $GOOGLE_PLAY_TRACK)..."
  if fastlane supply \
    --aab "$AAB_PATH" \
    --package_name "$PACKAGE_NAME" \
    --track "$GOOGLE_PLAY_TRACK" \
    --release_status completed \
    --json_key "$service_account" \
    --skip_upload_apk \
    --skip_upload_metadata \
    --skip_upload_images \
    --skip_upload_screenshots; then
    UPLOAD_STATUS="PASSED"
  else
    UPLOAD_STATUS="FAILED"
    fail_after_tag "Google Play upload failed."
  fi
}

print_release_plan() {
  log ""
  log "Latest tag:      ${LATEST_TAG}"
  log "Commits found:   ${COMMITS_COUNT}"
  log "Release type:    ${RELEASE_TYPE}"
  log "Version:         ${VERSION_NAME}"
  log "Version code:    ${VERSION_CODE}"
  log "Git tag:         ${RELEASE_TAG}"
  log "Tag status:      ${TAG_STATUS}"
  log "Tag action:      ${TAG_ACTION}"
  if [[ "$SKIP_VERIFY" != "1" ]]; then
    log "Verify:          WOULD RUN"
  else
    log "Verify:          WOULD SKIP (SKIP_VERIFY=1)"
  fi
  log "Build:           WOULD RUN with BUILD_NAME=${VERSION_NAME} BUILD_NUMBER=${VERSION_CODE}"
  if [[ "$UPLOAD" == "1" ]]; then
    if play_upload_configured; then
      log "Upload:          WOULD RUN (${GOOGLE_PLAY_TRACK})"
    else
      log "Upload:          WOULD FAIL (missing credentials)"
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
  if [[ "$DRY_RUN" == "1" ]]; then
    log "Mode:            $CD_MODE"
    log "Latest tag:      ${LATEST_TAG}"
    log "Commits found:   ${COMMITS_COUNT}"
    log "Release type:    ${RELEASE_TYPE}"
    log "Version:         ${VERSION_NAME}"
    log "Version code:    ${VERSION_CODE}"
    log "Git tag:         ${RELEASE_TAG}"
    log "Tag action:      ${TAG_ACTION}"
  else
    log "Version:         ${VERSION_NAME}"
    log "Version code:    ${VERSION_CODE}"
    log "Git tag:         ${RELEASE_TAG}"
    log "Verify:          ${VERIFY_STATUS}"
    log "AAB:             ${AAB_STATUS}"
    log "AAB path:        ${AAB_REL}"
    if [[ -n "$AAB_SIZE" ]]; then
      log "AAB size:        ${AAB_SIZE}"
    fi
    if [[ "$UPLOAD" == "1" ]]; then
      log "Google Play track: ${GOOGLE_PLAY_TRACK}"
      log "Google Play upload: ${UPLOAD_STATUS}"
    else
      log "Google Play upload: SKIPPED"
    fi
    if [[ "$TAG_ACTION" == "CREATED" ]]; then
      if [[ "$TAG_PUSHED" == "yes" ]]; then
        log "Git tag pushed:  yes"
      else
        log "Git tag pushed:  no (local only; GitHub mode sets PUSH_TAG=1)"
      fi
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
  resolve_release_version
  inspect_existing_tag || true
  ensure_release_tag

  if [[ "$DRY_RUN" == "1" ]]; then
    print_release_plan
    print_summary
    return
  fi

  validate_upload_prerequisites
  run_verify
  run_build
  verify_artifact
  upload_to_play
  print_summary
}

main "$@"
