# Tajeer AI — Mobile

The Flutter client for Tajeer AI: a realtime, offline-first Inbox for commerce
operators.

Built against the existing product rather than beside it — the visual language
comes from `packages/tajeerai-design-system`, and the socket protocol from the
backend's own contracts.

## What it is

- **Realtime-first.** WebSocket is the primary transport for business data.
  HTTP is used for the sign-in exchange and file transfer, and nothing else.
- **Offline-first.** The local database is the primary read source. Screens
  render from it whether or not there is a connection, and writes are queued
  durably until they can be sent.
- **Feature-first.** Each business capability owns its own presentation,
  application, domain and data layers.
- **Enforced.** The architecture is checked by a static guard that fails CI.

## Architecture

Read **[ARCHITECTURE.md](ARCHITECTURE.md)** — it is the authoritative
specification, and it is enforced rather than aspirational.

```
lib/
├── app/                Composition: bootstrap, routing, config, theme, localization
├── design_system/      Business-agnostic UI, from the shared design tokens
├── infrastructure/     Socket, database, storage, network, device, logging
├── failures/           The application-wide failure taxonomy
└── features/
    ├── auth/           Sign-in, session, socket credentials
    └── conversations/  The Inbox: rail, threads, sending, sync
```

Data flows one way:

```
Server → Socket → Feature handler → Repository → Local DB → Riverpod → UI
```

The UI never touches a socket, never touches the database, and never knows
whether what it is rendering arrived a second ago or a week ago.

## Getting started

Requires **Flutter 3.47.1** (Dart 3.13.1).

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Run it:

```bash
make run                  # against .env (or .env.development if you have none)
make run-staging
make run-prod
```

## Configuration

Build configuration lives in `.env` files, read natively by Flutter's
`--dart-define-from-file` — no runtime dependency, and the values are resolved
at compile time.

| File | Committed | Purpose |
| --- | --- | --- |
| `.env.development` | yes | Local backend. One Nest process serves both roles. |
| `.env.staging` | yes | `staging.tajeerai.com` — one host, both roles. |
| `.env.production` | yes | `api.tajeerai.com` and `socket.tajeerai.com`. |
| `.env.example` | yes | Template, documented. |
| `.env` | **no** | Your own overrides. Wins when present. |

```bash
cp .env.example .env      # then point TAJEER_API_URL at your LAN address
```

`10.0.2.2` is the host machine as seen from the Android emulator; a physical
device needs your LAN address.

**The API and the socket are separate hosts in production**
(`api.tajeerai.com`, `socket.tajeerai.com`); staging and development serve both
roles from one host. They are configured independently so that difference costs
nothing.

The split is safe for authentication: the session cookies the API sets are never
sent to the socket host, and the client never relied on them being — it reads
the access token out of the cookie jar and the handshake carries it as
`auth.token`.

> **These values are compiled into the binary and can be read back out of a
> shipped APK.** They are hostnames. Never put a secret, key or credential in
> one of these files.

## Commands

```bash
make verify      # everything CI runs, in CI's order
```

Individually:

```bash
make generate    # regenerate drift, Riverpod and JSON sources
make arch        # architecture guard
make format      # format lib, test and tool
make analyze     # static analysis, infos and warnings fatal
make test        # the test suite, with coverage
make coverage    # coverage thresholds
```

Without `make`:

```bash
dart run build_runner build --delete-conflicting-outputs
dart run tool/check_architecture.dart
dart format lib test tool
flutter analyze --fatal-infos --fatal-warnings
flutter test --coverage
dart run tool/check_coverage.dart
```

## Architecture guard

```bash
dart run tool/check_architecture.dart
```

Thirty rules covering layer direction, feature boundaries, forbidden
directories, presentation access, exception containment and generated code.
Each violation prints the rule, the offending line, why it is wrong and what to
use instead:

```
ARCHITECTURE VIOLATION

Rule:
RULE 14 - Feature A must not import Feature B data implementation.

Source:
lib/features/conversations/presentation/screens/conversation_screen.dart:12

Forbidden dependency:
lib/features/customers/data/repositories/customer_repository_impl.dart

Reason:
The conversations feature depends directly on customers' data layer. The two
can no longer be changed, tested or removed independently.

Allowed alternative:
Define what conversations needs as an interface in
features/customers/application/contracts/, implement it in customers, and wire
it in app/bootstrap/dependencies.dart.
```

Adding a rule means adding a file under `tool/architecture/rules/` and a line in
`_fileRules` — the checker is a rule registry, not a pile of string matches.

## Testing

**No test = incomplete implementation.** See
[ARCHITECTURE.md](ARCHITECTURE.md) §13.

```bash
flutter test                    # everything
flutter test test/features      # one area
flutter test --coverage && dart run tool/check_coverage.dart
```

Coverage: 80% overall, with higher floors on the domain, application, realtime,
DAO and failure layers. Business logic is tested without rendering Flutter;
persistence is tested against a real SQLite engine, not a mock.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Architecture checks and tests are both
mandatory.
