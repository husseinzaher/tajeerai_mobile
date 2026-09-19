#!/usr/bin/env bash
# Tests for tool/resolve_release_version.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RESOLVER="$ROOT/tool/resolve_release_version.sh"
ANDROID_RESOLVER="$ROOT/tool/resolve_android_version.sh"
CD_SCRIPT="$ROOT/scripts/release/android-cd.sh"

PASS=0
FAIL=0

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n' "$label" >&2
    printf '  expected: %s\n' "$expected" >&2
    printf '  actual:   %s\n' "$actual" >&2
  fi
}

assert_fail() {
  local label="$1"
  shift

  if "$@" >/dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s (expected failure)\n' "$label" >&2
  else
    PASS=$((PASS + 1))
    printf 'PASS: %s\n' "$label"
  fi
}

setup_repo() {
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR
  git -C "$TEST_DIR" init -q
  git -C "$TEST_DIR" config user.email "test@example.com"
  git -C "$TEST_DIR" config user.name "Test User"

  mkdir -p "$TEST_DIR/tool" "$TEST_DIR/scripts/release"
  cp "$RESOLVER" "$TEST_DIR/tool/resolve_release_version.sh"
  cp "$ANDROID_RESOLVER" "$TEST_DIR/tool/resolve_android_version.sh"
  cp "$CD_SCRIPT" "$TEST_DIR/scripts/release/android-cd.sh"
  chmod +x "$TEST_DIR/tool/"*.sh "$TEST_DIR/scripts/release/android-cd.sh"

  cat > "$TEST_DIR/pubspec.yaml" <<'EOF'
version: 1.0.2+1
EOF
}

commit() {
  printf '%s\n' "$1" >> "$TEST_DIR/CHANGELOG.test"
  git -C "$TEST_DIR" add -A
  git -C "$TEST_DIR" commit -qm "$1"
}

tag_version() {
  git -C "$TEST_DIR" tag -a "v$1" -m "Release v$1"
}

run_resolver() {
  (cd "$TEST_DIR" && bash tool/resolve_release_version.sh "$@")
}

run_cd_dry() {
  (cd "$TEST_DIR" && DRY_RUN=1 bash scripts/release/android-cd.sh --mode local 2>/dev/null)
}

cleanup_repo() {
  rm -rf "$TEST_DIR"
}

test_no_previous_tag_uses_pubspec() {
  setup_repo
  commit "chore: bootstrap"
  assert_eq "no tag uses pubspec name" "1.0.2" "$(run_resolver name)"
  assert_eq "no tag uses pubspec tag" "v1.0.2" "$(run_resolver tag)"
  assert_eq "no tag type" "INITIAL" "$(run_resolver type)"
  cleanup_repo
}

test_fix_commits_bump_patch() {
  setup_repo
  commit "chore: bootstrap"
  tag_version "1.0.0"
  commit "fix: fix login validation"
  commit "chore: update dependencies"
  assert_eq "fix commits next version" "1.0.1" "$(run_resolver name)"
  assert_eq "fix commits type" "PATCH" "$(run_resolver type)"
  cleanup_repo
}

test_feat_commit_bumps_minor() {
  setup_repo
  commit "chore: bootstrap"
  tag_version "1.0.0"
  commit "feat: add order analytics"
  assert_eq "feat next version" "1.1.0" "$(run_resolver name)"
  assert_eq "feat type" "MINOR" "$(run_resolver type)"
  cleanup_repo
}

test_breaking_change_bumps_major() {
  setup_repo
  commit "chore: bootstrap"
  tag_version "1.1.0"
  commit "feat!: redesign authentication API"
  assert_eq "breaking next version" "2.0.0" "$(run_resolver name)"
  assert_eq "breaking type" "MAJOR" "$(run_resolver type)"
  cleanup_repo
}

test_mixed_fix_and_feat_bumps_minor() {
  setup_repo
  commit "chore: bootstrap"
  tag_version "1.0.0"
  commit "fix: improve error handling"
  commit "feat: add analytics"
  assert_eq "mixed next version" "1.1.0" "$(run_resolver name)"
  assert_eq "mixed type" "MINOR" "$(run_resolver type)"
  cleanup_repo
}

test_breaking_and_feat_bumps_major() {
  setup_repo
  commit "chore: bootstrap"
  tag_version "1.1.0"
  commit "feat: add dashboard"
  commit "feat!: remove legacy auth"
  assert_eq "breaking + feat next version" "2.0.0" "$(run_resolver name)"
  assert_eq "breaking + feat type" "MAJOR" "$(run_resolver type)"
  cleanup_repo
}

test_invalid_commit_fails() {
  setup_repo
  commit "chore: bootstrap"
  tag_version "1.0.0"
  commit "updated login screen"
  assert_fail "invalid commit fails" run_resolver name
  cleanup_repo
}

test_no_commits_since_latest_tag_reuses_version() {
  setup_repo
  commit "chore: bootstrap"
  tag_version "1.0.0"
  assert_eq "reuse version" "1.0.0" "$(run_resolver name)"
  assert_eq "reuse type" "REUSE" "$(run_resolver type)"
  cleanup_repo
}

test_tag_exists_on_other_commit_is_detected() {
  setup_repo
  commit "chore: bootstrap"
  tag_version "1.0.0"
  commit "fix: one"
  git -C "$TEST_DIR" tag -a "v1.0.1" "$(git -C "$TEST_DIR" rev-parse HEAD~1)" -m "conflict"

  if git -C "$TEST_DIR" rev-parse "v1.0.1^{commit}" >/dev/null 2>&1 &&
    [[ "$(git -C "$TEST_DIR" rev-parse v1.0.1^{commit})" != "$(git -C "$TEST_DIR" rev-parse HEAD)" ]]; then
    PASS=$((PASS + 1))
    printf 'PASS: tag exists on other commit is detectable\n'
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: tag exists on other commit is detectable\n' >&2
  fi

  cleanup_repo
}

test_dry_run_does_not_create_tag() {
  setup_repo
  commit "chore: bootstrap"
  tag_version "1.0.0"
  commit "fix: login"
  run_cd_dry >/dev/null
  assert_eq "dry run tag count" "1" "$(git -C "$TEST_DIR" tag -l | wc -l | tr -d ' ')"
  cleanup_repo
}

test_version_code_encoding() {
  setup_repo
  commit "chore: bootstrap"
  tag_version "1.2.3"
  commit "fix: patch"
  assert_eq "version code" "1002004" "$(run_resolver number)"
  cleanup_repo
}

main() {
  test_no_previous_tag_uses_pubspec
  test_fix_commits_bump_patch
  test_feat_commit_bumps_minor
  test_breaking_change_bumps_major
  test_mixed_fix_and_feat_bumps_minor
  test_breaking_and_feat_bumps_major
  test_invalid_commit_fails
  test_no_commits_since_latest_tag_reuses_version
  test_tag_exists_on_other_commit_is_detected
  test_dry_run_does_not_create_tag
  test_version_code_encoding

  printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
  if (( FAIL > 0 )); then
    exit 1
  fi
}

main "$@"
