# Developer commands. `make verify` runs exactly what CI runs.
#
# Flutter is invoked by name; ensure it is on your PATH.

.PHONY: help setup tokens tokens-check generate watch migrations arch format format-check analyze \
        test golden golden-update coverage verify clean run run-staging run-prod run-prod-dev \
        showcase showcase-build google-sign-in-setup google-sign-in-check \
        build-prod build-staging android-build cd cd-local

# Build configuration comes from a .env file, read natively by Flutter's
# --dart-define-from-file. A local `.env` (gitignored) wins when present, so a
# developer on a physical device can point at their LAN address without editing
# a committed file.
ENV_FILE ?= $(firstword $(wildcard .env) .env.development)

help:
	@echo "setup         Install dependencies and generate code"
	@echo "tokens        Regenerate the theme from design/tokens.json"
	@echo "tokens-check  Fail if the generated theme is stale"
	@echo "generate      Regenerate the theme, drift, Riverpod and JSON sources"
	@echo "watch         Regenerate continuously while developing"
	@echo "migrations    Snapshot a new database schema version"
	@echo "run           Run against $(ENV_FILE)"
	@echo "showcase      Run the design system on its own, in a browser"
	@echo "run-staging   Run against .env.staging"
	@echo "run-prod      Run against .env.production"
	@echo "run-prod-dev  Production backend, debug build (hot reload)"
	@echo "build-prod    Release APK against .env.production"
	@echo "android-build Release App Bundle for Google Play (.aab)"
	@echo "cd            Android CD pipeline (MODE=local|github)"
	@echo "cd-local      Local Android CD: conventional commits, tag, build signed AAB"
	@echo "arch          Run the architecture guard"
	@echo "format        Format lib, test and tool"
	@echo "analyze       Static analysis (infos and warnings fatal)"
	@echo "test          Run the test suite with coverage"
	@echo "golden        Run only the pixel comparisons"
	@echo "golden-update Re-bless the pixel comparisons"
	@echo "coverage      Check coverage thresholds"
	@echo "google-sign-in-setup  Write iOS Google Sign-In keys into Info.plist from .env"
	@echo "google-sign-in-check  Fail if Info.plist is stale"
	@echo "google-android-sha1   Print debug SHA-1 for Google Cloud Console"
	@echo "verify        Everything CI runs, in CI's order"

setup:
	flutter pub get
	$(MAKE) generate

# The design system's foundation. `design/tokens.json` is the single source of
# truth for every colour, type step, spacing step, radius, elevation and motion
# value; this writes lib/app/theme/tokens.g.dart from it. Nothing else compiles
# without it, which is why it runs before build_runner.
tokens:
	dart run tool/build_tokens.dart

tokens-check:
	dart run tool/build_tokens.dart --check

generate: tokens
	dart run build_runner build --delete-conflicting-outputs

watch:
	dart run build_runner watch --delete-conflicting-outputs

# After changing a table and bumping SchemaMigrations.version. Snapshots the
# schema into drift_schemas/, regenerates the stepByStep helper beside the
# database, and the schemas the migration tests open. Formats what it wrote,
# because the generator's output is committed.
migrations:
	dart run drift_dev make-migrations
	dart format lib/infrastructure/database test/drift

run:
	flutter run --dart-define-from-file=$(ENV_FILE)

# The design system, with none of the app around it.
#
# A second entry point rather than a second project: it mounts the same
# ShowcaseApp the in-app /design-system route does, which mounts the same
# production components every screen does. It exists because main.dart opens a
# database, a socket and a secure store before it shows anything, and a browser
# has none of those.
showcase:
	flutter run -t lib/main_showcase.dart -d chrome

showcase-build:
	flutter build web -t lib/main_showcase.dart --no-tree-shake-icons

run-staging:
	flutter run --dart-define-from-file=.env.staging

run-prod:
	flutter run --release --dart-define-from-file=.env.production

# Production backend in debug mode — hot reload works; use this while developing.
run-prod-dev:
	flutter run --dart-define-from-file=.env.production

build-staging:
	flutter build apk --release --dart-define-from-file=.env.staging

build-prod:
	flutter build apk --release --dart-define-from-file=.env.production

google-sign-in-setup:
	dart run tool/configure_google_sign_in.dart

google-sign-in-check:
	dart run tool/configure_google_sign_in.dart --check

# Debug keystore SHA-1 for the Android OAuth client in Google Cloud Console.
google-android-sha1:
	cd android && ./gradlew :app:signingReport 2>&1 | grep -A6 'Variant: debug' | grep 'SHA1:'

arch:
	dart run tool/check_architecture.dart

format:
	dart format lib test tool

format-check:
	dart format --output=none --set-exit-if-changed lib test tool

analyze:
	flutter analyze --fatal-infos --fatal-warnings

test:
	flutter test --coverage

# The pixel comparisons. They are the only tests whose result depends on how
# the machine rasterises a font, so an environment that cannot reproduce the
# reference rendering runs `flutter test --exclude-tags golden` instead of
# blessing a diff.
golden:
	flutter test --tags golden

# Deliberate, never a reflex: a regenerated image is a design change, and the
# point of two variants per page rather than four is that a human can review
# every one that moved. See ARCHITECTURE.md §13.
golden-update:
	flutter test --tags golden --update-goldens

coverage:
	dart run tool/check_coverage.dart

# The order matters: a layering violation explains failures that would
# otherwise look like unrelated compile errors, so the guard runs early.
verify: generate arch format-check analyze test coverage
	@echo ""
	@echo "All checks passed."

clean:
	flutter clean
	rm -rf coverage

# --- Android / Flutter --------------------------------------------------------

# Release builds pass BUILD_NAME/BUILD_NUMBER from the CD pipeline.
# Dev builds fall back to the latest Git tag, then pubspec.yaml.
# versionCode = major*1_000_000 + minor*1_000 + patch (see tool/resolve_android_version.sh).
ANDROID_BUILD_NAME ?= $(shell bash tool/resolve_android_version.sh name)
ANDROID_BUILD_NUMBER ?= $(shell bash tool/resolve_android_version.sh number)

android-build: ## Build a signed release App Bundle for Google Play
	@test -f android/key.properties || test -f android/app/key.properties || \
		(echo "Missing android/key.properties. Copy android/key.properties.example and configure the upload keystore." >&2; exit 1)
	flutter clean
	flutter pub get
	flutter build appbundle --release \
		--build-name="$(ANDROID_BUILD_NAME)" \
		--build-number="$(ANDROID_BUILD_NUMBER)" \
		--dart-define-from-file=.env.production
	@test -f build/app/outputs/bundle/release/app-release.aab
	@echo ""
	@echo "Android App Bundle generated:"
	@echo "  build/app/outputs/bundle/release/app-release.aab"
	@echo "  versionName=$(ANDROID_BUILD_NAME)  versionCode=$(ANDROID_BUILD_NUMBER)"

MODE ?= local

cd: ## Run the shared Android CD pipeline (MODE=local|github)
	ALLOW_DIRTY="$(ALLOW_DIRTY)" SKIP_VERIFY="$(SKIP_VERIFY)" DRY_RUN="$(DRY_RUN)" \
		PUSH_TAG="$(PUSH_TAG)" UPLOAD="$(UPLOAD)" GOOGLE_PLAY_TRACK="$(GOOGLE_PLAY_TRACK)" \
		bash scripts/release/android-cd.sh --mode "$(MODE)"

cd-local: ## Run the local Android CD pipeline
	$(MAKE) cd MODE=local
