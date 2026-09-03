# Contributing

## Setup

Requires Flutter 3.47.1 (Dart 3.13.1) — the version CI pins.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

## Running the app

Configuration comes from `.env` files, read by Flutter's
`--dart-define-from-file`. Copy the template and point it at your backend:

```bash
cp .env.example .env
make run
```

`10.0.2.2` is the host machine as seen from the Android emulator; a physical
device needs your LAN address.

`.env` is gitignored and takes precedence over `.env.development`, so you can
work on a device without editing a committed file. Other deployments:

```bash
make run-staging
make run-prod
make build-prod
```

The API and the socket are separate hosts in staging and production
(`TAJEER_API_URL` and `TAJEER_SOCKET_URL`). Setting only `TAJEER_API_URL`
points both at it, which is what a single local backend wants.

> These values are compiled into the binary and are extractable from a shipped
> APK. They are hostnames — never put a secret in one.

## The checks

**All of these are mandatory and all of them run in CI.** Run them locally
before opening a pull request:

```bash
make verify
```

which is:

```bash
dart run build_runner build --delete-conflicting-outputs
dart run tool/check_architecture.dart
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze --fatal-infos --fatal-warnings
flutter test --coverage
dart run tool/check_coverage.dart
```

Individually:

| Command | Checks |
| --- | --- |
| `make generate` | Regenerates drift, Riverpod and JSON sources. |
| `make arch` | Architecture guard — layering and feature boundaries. |
| `make format` | Formatting. |
| `make analyze` | Static analysis, with infos and warnings fatal. |
| `make test` | The full test suite. |
| `make coverage` | Coverage thresholds. |

## Architecture checks are mandatory

`dart run tool/check_architecture.dart` enforces the rules in
[ARCHITECTURE.md](ARCHITECTURE.md). A violation prints the rule, the offending
line, why it is wrong and what to use instead, and fails the build.

**Fix the violation. Do not weaken the rule.** If a rule is genuinely wrong,
change it deliberately: update `ARCHITECTURE.md`, the rule in
`tool/architecture/rules/`, and the guard's own tests, in one change.

## Tests are mandatory

**No test = incomplete implementation.** See [ARCHITECTURE.md](ARCHITECTURE.md)
§13 for what each layer requires. A pull request adding production logic without
tests will fail the coverage gate.

For a bug fix: write the failing test first, then fix it, and keep the test.

## Adding a feature

1. Create `lib/features/<name>/` with only the layers you need.
2. Rules go in `domain/services/`, workflows in `application/coordinators/`,
   screen state in `presentation/controllers/`.
3. If another feature needs something from yours, publish an interface in
   `application/contracts/` and wire it in `app/bootstrap/dependencies.dart`.
   Never let another feature import your internals.
4. Write the tests as you go.
5. Run `make verify`.

The guard checks new features automatically — nothing in it enumerates feature
names.

## Adding a dependency

Justify it. Prefer what is already here. Record what it is for in the pull
request, and — if it changes how a layer works — in `ARCHITECTURE.md`.
