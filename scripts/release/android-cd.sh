#!/usr/bin/env bash
# Local Android CD pipeline for Tajeer AI mobile.
#
# Validates repository state, resolves version from the release Git tag,
# runs verification, builds a signed App Bundle, and optionally uploads to
# Google Play. Designed to be invoked by `make cd-local` and reusable from
# future CI without GitHub-specific logic.
#
# Environment overrides:
#   ALLOW_DIRTY=1   Continue with uncommitted changes (default: fail)
#   SKIP_VERIFY=1   Skip `make verify` (default: run verify)
#   DRY_RUN=1       Validate and print planned steps only (no build/upload)
#   UPLOAD=1        Upload the AAB to Google Play after a successful build
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AAB_REL="build/app/outputs/bundle/release/app-release.aab"
AAB_PATH="$ROOT/$AAB_REL"
PACKAGE_NAME="com.tajeerai.mobile"
RELEASE_TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+$'

ALLOW_DIRTY="${ALLOW_DIRTY:-0}"
SKIP_VERIFY="${SKIP_VERIFY:-0}"
DRY_RUN="${DRY_RUN:-0}"
UPLOAD="${UPLOAD:-0}"

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

print_planned() {
  log "Would run: $*"
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

validate_release_tag() {
  mapfile -t matching_tags < <(
    git -C "$ROOT" tag --points-at HEAD --list 'v[0-9]*.[0-9]*.[0-9]*' | sort -u
  )

  if ((${#matching_tags[@]} == 0)); then
    fail "HEAD is not on a release tag. Check out an annotated release tag such as v1.0.0 before running CD."
  fi

  if ((${#matching_tags[@]} > 1)); then
    fail "Multiple release tags point at HEAD: ${matching_tags[*]}. Use a single unambiguous tag."
  fi

  RELEASE_TAG="${matching_tags[0]}"

  if [[ ! "$RELEASE_TAG" =~ $RELEASE_TAG_PATTERN ]]; then
    fail "Release tag '$RELEASE_TAG' is invalid. Expected format: vMAJOR.MINOR.PATCH (example: v1.2.3)."
  fi

  local exact_tag
  exact_tag="$(git -C "$ROOT" describe --tags --exact-match HEAD 2>/dev/null || true)"

  if [[ "$exact_tag" != "$RELEASE_TAG" ]]; then
    fail "HEAD must be exactly on release tag $RELEASE_TAG (git describe --exact-match mismatch)."
  fi
}

resolve_version() {
  VERSION_NAME="$(bash "$ROOT/tool/resolve_android_version.sh" name)"
  VERSION_CODE="$(bash "$ROOT/tool/resolve_android_version.sh" number)"

  if [[ -z "$VERSION_NAME" || -z "$VERSION_CODE" ]]; then
    fail "Version resolver returned empty values."
  fi

  local expected="${RELEASE_TAG#v}"
  if [[ "$VERSION_NAME" != "$expected" ]]; then
    fail "Version resolver produced versionName=$VERSION_NAME but release tag is $RELEASE_TAG."
  fi
}

run_verify() {
  if [[ "$SKIP_VERIFY" == "1" ]]; then
    log "WARNING: SKIP_VERIFY=1 — skipping make verify."
    return
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    print_planned "make verify"
    return
  fi

  log "Running make verify..."
  make -C "$ROOT" verify
}

run_build() {
  if [[ "$DRY_RUN" == "1" ]]; then
    print_planned "make android-build"
    return
  fi

  log "Running make android-build..."
  make -C "$ROOT" android-build
}

verify_artifact() {
  if [[ "$DRY_RUN" == "1" ]]; then
    print_planned "test -s $AAB_REL"
    AAB_SIZE="(dry run)"
    return
  fi

  [[ -f "$AAB_PATH" ]] || fail "Expected AAB not found at $AAB_REL."
  [[ -s "$AAB_PATH" ]] || fail "AAB exists but is empty: $AAB_REL."

  AAB_SIZE="$(human_size "$(wc -c < "$AAB_PATH" | tr -d ' ')")"
}

play_upload_configured() {
  local service_account="${GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:-$ROOT/android/play-service-account.json}"

  [[ -f "$service_account" ]]
}

upload_to_play() {
  local service_account="${GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:-$ROOT/android/play-service-account.json}"
  local track="${GOOGLE_PLAY_TRACK:-internal}"

  if [[ "$DRY_RUN" == "1" ]]; then
    print_planned "fastlane supply --aab $AAB_REL --package_name $PACKAGE_NAME --track $track --json_key <service-account> --skip_upload_apk --skip_upload_metadata --skip_upload_images --skip_upload_screenshots"
    return
  fi

  if ! play_upload_configured; then
    fail "Google Play upload is not configured. Set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON to a service-account JSON file, or place the file at android/play-service-account.json (gitignored)."
  fi

  require_command fastlane

  log "Uploading AAB to Google Play (track: $track)..."

  fastlane supply \
    --aab "$AAB_PATH" \
    --package_name "$PACKAGE_NAME" \
    --track "$track" \
    --json_key "$service_account" \
    --skip_upload_apk \
    --skip_upload_metadata \
    --skip_upload_images \
    --skip_upload_screenshots
}

print_summary() {
  log ""
  log "========================================"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "Android CD dry run completed"
  else
    log "Android CD completed successfully"
  fi
  log "========================================"
  log "Tag:          $RELEASE_TAG"
  log "Version:      $VERSION_NAME"
  log "Version code: $VERSION_CODE"
  if [[ "$DRY_RUN" != "1" ]]; then
    log "Artifact:     $AAB_REL"
    log "Size:         $AAB_SIZE"
  fi
  if [[ "$UPLOAD" == "1" ]]; then
    if play_upload_configured; then
      log "Upload:       Google Play (${GOOGLE_PLAY_TRACK:-internal})"
    else
      log "Upload:       requested but not configured"
    fi
  else
    log "Upload:       skipped (set UPLOAD=1 to enable)"
  fi
  log "========================================"
}

main() {
  cd "$ROOT"

  validate_commands
  validate_clean_worktree
  validate_release_tag
  resolve_version

  log "Release tag:  $RELEASE_TAG"
  log "Version:      $VERSION_NAME"
  log "Version code: $VERSION_CODE"

  if [[ "$DRY_RUN" == "1" ]]; then
    log ""
    log "DRY_RUN=1 — planned steps:"
  fi

  run_verify
  run_build
  verify_artifact

  if [[ "$UPLOAD" == "1" ]]; then
    upload_to_play
  fi

  print_summary
}

main "$@"
