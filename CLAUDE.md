# Working in this repository

This is the Tajeer AI Flutter client. It has an enforced architecture.

**Read [ARCHITECTURE.md](ARCHITECTURE.md) before modifying application code.**
It is mandatory, not advisory.

> **Architecture violations are defects, not stylistic differences.**

---

## Before you write code

1. **Read `ARCHITECTURE.md`.** Read the sections your change touches. If you are
   adding a feature, read §3, §4, §5 and §6 in full.
2. **Inspect the design system.** `packages/tajeerai-design-system/tokens.json`
   is the source of truth for every visual value. Never invent a colour,
   radius, spacing step or font.
3. **Look for what already exists.** Search `design_system/` before adding a
   widget, `domain/services/` before adding a rule, and the existing feature
   before adding a folder.

## While you write code

**Preserve feature boundaries.** A feature never imports another feature's
presentation, data, realtime or domain. The only door is
`application/contracts/`. See `SessionCapability` for the worked example.

**Never bypass a layer.** Screen → Controller → Application/Domain →
Repository. A widget that calls a repository, a controller that opens the
database, or a domain service that imports Dio is a defect regardless of
whether it works.

**Never introduce a forbidden folder.** `core/`, `shared/`, `helpers/`,
`utils/`, `misc/`, `common/`, `presentation/providers/`. If code has no obvious
home, that is a signal about the code, not a reason for a new folder.

**Keep the domain framework-free.** No Flutter, no Riverpod, no Dio, no drift,
no socket, no device APIs in `domain/`. Business rules must be testable with a
fake repository and nothing else.

**Do not make HTTP the default transport.** WebSocket carries business data.
HTTP is for the sign-in exchange, file transfer, and endpoints the socket does
not expose. A new HTTP call needs a reason recorded in `ARCHITECTURE.md` §11.

**Preserve realtime-first.** Socket events are written to the database by a
feature's realtime handler; the UI watches the database. A widget must never
subscribe to a socket.

**Preserve offline-first.** The database is the primary read source. Reads do
not make network calls. Writes go through the outbox so they survive being
offline and survive the process dying.

**Use the design system.** Semantic tokens only. Both light and dark. Logical
directions so Arabic and English share one implementation.

**Keep infrastructure exceptions contained.** `HttpException` and
`SocketException` are translated to an `AppFailure` at the data boundary and
never travel further.

## Testing is part of the change

**No test = incomplete implementation.**

Every new production file, and every meaningful change to an existing one, needs
tests. See `ARCHITECTURE.md` §13 for what each layer requires.

- Business rules get unit tests that do not render Flutter.
- Realtime handlers get valid, malformed, unknown, duplicate and ordering tests.
- Offline behaviour gets read-offline, write-offline, retry-after-reconnect and
  acknowledgement tests.
- Widgets get loading, error, empty and success state tests.
- Bug fixes are test-first: reproduce in a failing test, then fix.

Do not write tests that only move the coverage number.

## Before you finish

Run all of it. Every step also runs in CI, and CI failing on something you could
have caught locally is wasted time for everyone.

```bash
dart run build_runner build --delete-conflicting-outputs
dart run tool/check_architecture.dart
dart format lib test tool
flutter analyze --fatal-infos --fatal-warnings
flutter test --coverage
dart run tool/check_coverage.dart
```

Or, in one command:

```bash
make verify
```

**Fix violations. Do not suppress them.** Do not add an `// ignore:`, lower a
coverage threshold, or weaken a guard rule to make a check pass. If a rule is
genuinely wrong, that is a change to `ARCHITECTURE.md` and to the guard,
proposed deliberately — not a workaround in the file that tripped it.

## Changing the architecture

`ARCHITECTURE.md` is updated only for an intentional, approved architectural
change — never to describe a violation after the fact. When it does change:

1. Update `ARCHITECTURE.md`.
2. Update `tool/architecture/rules/` so the new rule is enforced.
3. Update the guard's tests in `test/tool/`.
4. Bring the codebase into line in the same change.

## Where things are

| Looking for | Go to |
| --- | --- |
| A business rule | `features/<f>/domain/services/` |
| A multi-step workflow | `features/<f>/application/coordinators/` |
| Screen state | `features/<f>/presentation/controllers/` |
| A socket command | `features/<f>/data/remote/` |
| Socket event handling | `features/<f>/realtime/` |
| A shared widget | `design_system/` |
| Dependency wiring | `app/bootstrap/dependencies.dart` |
| A colour or spacing value | `app/theme/` (sourced from `tokens.json`) |
| Error types | `failures/app_failure.dart` |
| The backend contract | `backend/src/contracts/schemas/conversation-socket.ts` |
