# Working in this repository

This is the Tajeer AI Flutter client. It has an enforced architecture.

**Read [ARCHITECTURE.md](ARCHITECTURE.md) before modifying application code.**
It is mandatory, not advisory.

> **Architecture violations are defects, not stylistic differences.**

---

## Before you write code

1. **Read `ARCHITECTURE.md`.** Read the sections your change touches. If you are
   adding a feature, read §3, §4, §5 and §6 in full.
2. **Inspect the design system — this one, not the web one.**
   `lib/design_system/` is where every reusable component lives, and
   `design/tokens.json` is the source of truth for every visual value. Never
   invent a colour, radius, spacing step or font.

   **`packages/tajeerai-design-system/` is the WEB design system and is not a
   source of truth for mobile.** It cannot be imported, so the rule is about
   copying: its dimensions, spacing, interaction models and touch targets were
   designed for a pointer. A popover is a bottom sheet here.

3. **Follow Design System First.** In order: reuse the component; extend it
   with a variant if it nearly fits; if the missing pattern is reusable, build
   it *in the design system* — both appearances, both directions, its states —
   and then use it. Only a genuinely feature-specific thing is built inside a
   feature. `LoginButton`, `InboxCard` and `ConversationInput` are the shapes
   this forbids. See `ARCHITECTURE.md` §12.
4. **Look for what already exists.** Search `design_system/` before adding a
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
HTTP is for the sign-in exchange, file transfer, and the workspace data §11
lists because the socket does not expose it. A new kind of HTTP call needs a
reason recorded in `ARCHITECTURE.md` §11, and RULE 36 keeps every call in a
feature's `data/remote/`.

**Preserve realtime-first.** Socket events are written to the database by a
feature's realtime handler; the UI watches the database. A widget must never
subscribe to a socket.

**Preserve offline-first.** The database is the primary read source. Reads do
not make network calls. Writes go through the outbox so they survive being
offline and survive the process dying.

**Use the design system.** Import it through `design_system/design_system.dart`
— that is the only door a feature has, and RULE 31 enforces it. Semantic tokens
only, never a hex or an off-scale number: outside `design_system/` and
`app/theme/`, RULE 34 fails a raw colour, font size or family, and a number
where a radius or spacing token belongs, and RULE 35 fails a Material widget
the system already wraps (`Checkbox(`, `ListTile(`, `showDialog(`), naming the
component to use. Both appearances of **both presets**:
`aurora` and `tajeer` declare the same names, so a component that reads tokens
is correct in all four without knowing which it is in. Logical directions so
Arabic and English share one implementation.

**A design-system file imports its siblings by leaf path, never the barrel**,
and may reach `app/theme/` but nothing else under `app/` (RULE 32). It must not
import Riverpod, go_router, Dio, drift or a storage package (RULE 33): take the
value as a parameter and report the change through a callback.

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
- A change that moves pixels regenerates its goldens with `make golden-update`,
  and every image that changed is looked at before it is committed
  (`ARCHITECTURE.md` §13).
- Bug fixes are test-first: reproduce in a failing test, then fix.

Do not write tests that only move the coverage number.

## Before you finish

Run all of it. Every step also runs in CI, and CI failing on something you could
have caught locally is wasted time for everyone.

```bash
dart run tool/build_tokens.dart
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
| Dependency wiring | `app/bootstrap/dependencies.dart` |
| A shared component | `design_system/`, reached via `design_system.dart` |
| The signed-in frame (drawer, bottom bar) | `app/shell/authenticated_shell.dart`, built from `design_system/shell/` |
| A colour, type step or spacing value | `design/tokens.json`, generated into `app/theme/tokens.g.dart` |
| Error types | `failures/app_failure.dart` |
| The backend contract | `backend/src/modules/conversation/application/contracts/conversation-socket.ts` |
