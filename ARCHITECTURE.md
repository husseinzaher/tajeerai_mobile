# Architecture

This document is the authoritative specification for the Tajeer AI mobile
client. It is enforced, not aspirational: `dart run tool/check_architecture.dart`
checks most of what follows and fails CI when it is violated.

**Architecture violations are defects, not stylistic differences.**

---

## 1. Shape of the system

Four ideas, in combination:

| Idea | What it means here |
| --- | --- |
| **Feature-first** | Code is organised by business capability, not by technical kind. All of "conversations" lives in one directory. |
| **Vertical slice** | Each feature owns its own presentation, application, domain and data layers, and is understandable without reading another feature. |
| **Realtime-first** | WebSocket is the primary transport for business data. HTTP is secondary and every use of it is justified. |
| **Offline-first** | The local database is the primary read source. The UI renders from it, online or not. |

The consequence worth stating plainly: **the UI never knows where its data came
from.** A message on screen looks identical whether it arrived over the socket a
second ago, was read from disk after a week offline, or was composed locally and
has not left the device. Everything writes to the database; the UI watches the
database.

---

## 2. Root structure

```
lib/
├── main.dart                  Entry point. Resolves config, opens the database, runs the app.
│
├── app/                       Composition only -- never business logic.
│   ├── app.dart               The root widget: theme, locale, router, session-to-socket wiring.
│   ├── bootstrap/
│   │   └── dependencies.dart  The entire dependency graph, in one file.
│   ├── router/
│   │   ├── app_router.dart    go_router configuration.
│   │   ├── routes.dart        Every path and route name.
│   │   └── guards/            Pure redirect decisions.
│   ├── config/
│   │   ├── app_config.dart    Resolved configuration for one run.
│   │   └── environment.dart   Which deployment this build points at.
│   ├── theme/                 Design tokens: colors, typography, spacing, radii, shadows, motion.
│   └── localization/          Locale selection and copy.
│
├── design_system/             Business-agnostic UI. Knows nothing about conversations or auth.
│   ├── atoms/ buttons/ inputs/ cards/ dialogs/ sheets/ snackbars/ loaders/ layouts/ feedback/
│
├── infrastructure/            Technical implementations. Business-agnostic.
│   ├── realtime/              Generic socket engine: connect, reconnect, authenticate, encode.
│   ├── database/              Drift engine, migrations, and the business-agnostic tables.
│   ├── storage/               Secure storage, preferences, files.
│   ├── network/               HTTP client and interceptors.
│   ├── device/                Connectivity, platform info.
│   └── logging/               Logger and crash reporting.
│
├── failures/                  The application-wide failure taxonomy. Depends on nothing.
│
└── features/                  One directory per business capability.
    ├── auth/
    └── conversations/
```

### Why `failures/` is a top-level directory

It is the one thing every layer may import, including the framework-free
domain. That is only safe while it depends on nothing at all, which the guard
enforces: `lib/failures/` may not import any package, or any project file
outside itself. It holds one sealed hierarchy and no business rules.

It is **not** `shared/` under another name. A second responsibility added here
turns it into exactly the dumping ground rule 20 forbids, and the guard will
reject the import that does it.

### Forbidden directories

`core/`, `shared/`, `helpers/`, `utils/`, `misc/`, `common/`, and any
`presentation/providers/` folder. Each attracts code that belongs somewhere
specific. Riverpod is an implementation mechanism, not a layer — providers are
declared beside the controller that owns them.

---

## 3. Feature structure

```
features/<feature>/
├── presentation/
│   ├── screens/               Route destinations.
│   ├── widgets/               Feature-specific widgets.
│   └── controllers/           Screen state and actions. Providers live here.
│
├── application/
│   ├── contracts/             What OTHER features may use. The only public door.
│   ├── events/                Facts this feature announces.
│   ├── state/                 State shared across more than one screen.
│   └── coordinators/          Multi-step workflows.
│
├── domain/
│   ├── entities/              Business objects with behaviour.
│   ├── value_objects/         Validated values (MessageContent, Password).
│   ├── repositories/          Data-access contracts. Interfaces only.
│   └── services/              Business rules.
│
├── data/
│   ├── models/                Wire-format decoding.
│   ├── local/                 DAOs and table declarations.
│   ├── remote/                Socket commands (and HTTP, where justified).
│   └── repositories/          Implementations of the domain contracts.
│
└── realtime/                  Only when the feature owns realtime behaviour.
```

A feature creates a directory when it has something to put in it. Empty
directories mirroring another feature's shape are noise.

---

## 4. Domain versus application

The distinction is exact, and it is where most architectural drift starts.

| | Question it answers | Example |
| --- | --- | --- |
| **Domain** | *What does the business allow?* | "Archived conversations cannot receive new messages." |
| **Application** | *How does the app coordinate the workflow?* | "Persist pending → send socket command → handle the acknowledgement → update local state." |

`ConversationService.canSendTo` is a rule and lives in `domain/services/`.
`OutboxCoordinator.drain` is a sequence and lives in
`application/coordinators/`.

Rules never move into controllers, coordinators, or infrastructure. Coordinators
never accumulate rules — a coordinator with a `switch` on business state is a
domain service wearing the wrong name.

There is deliberately no `application/services/`. Business services belong to
the domain.

---

## 5. Dependency rules

```
Presentation  →  Application  →  Domain  ←  Data  →  Infrastructure
                                   ↑
                            (everything may import lib/failures/)
```

Arrows point at what a layer may import.

**Presentation** may import application, domain, the design system, and
`app/bootstrap/dependencies.dart`. Never data. Never infrastructure. A widget
may not import a repository at all — that is a controller's job.

**Application** may import domain, data contracts, and infrastructure
abstractions. Never presentation. Never Flutter.

**Domain** imports nothing but Dart and `lib/failures/`. No Flutter, no
Riverpod, no Dio, no drift, no socket, no device APIs. This is what makes every
business rule testable with a fake repository and nothing else.

**Data** implements domain contracts and may use infrastructure. It is the
translation boundary — see §9.

**Infrastructure** may import nothing from `features/`, with one documented
exception: `AppDatabase` imports each feature's table and DAO declarations,
because drift generates one schema for one database. The guard narrows the
exception to that file and to `*_tables.dart` / `*_dao.dart` targets, so it
cannot be used as a general escape hatch. The alternative — moving every
feature's schema into infrastructure — would be the worse violation.

**Design system** may import nothing from `features/`. A shared component that
knows what a conversation is can no longer be shared.

---

## 6. Feature boundaries

A feature must never reach into another feature's internals — not its
presentation, not its data, not its realtime, not even its domain.

**The only supported door is `application/contracts/`.**

Worked example, and the one in the codebase: the Conversations feature needs the
signed-in user's id, and offers a sign-out button. It depends on
`features/auth/application/contracts/session_capability.dart` — an interface
saying what it needs. `SessionCoordinator` implements it, and
`dependencies.dart` joins the two. Conversations does not know
`SessionCoordinator` exists; auth does not know who is listening.

The guard enforces this for every feature, including ones that do not exist
yet — nothing in the rule enumerates feature names.

---

## 7. Realtime architecture

The backend is a NestJS Socket.IO gateway. Its contract lives in
`backend/src/contracts/schemas/conversation-socket.ts`, and this client is built
against it rather than against an invented protocol.

### Read path

```
Server
  → Socket.IO frame
  → SocketConnection            (transport: decodes frames)
  → SocketManager               (lifecycle: connect, reconnect, credentials)
  → ConversationSocketHandler   (feature: interprets THIS event)
  → Repository                  (writes)
  → Local database
  → Reactive query
  → Riverpod
  → UI
```

The UI never subscribes to a socket. It watches the database.

### Layer split

`infrastructure/realtime/` is business-agnostic: it connects, reconnects,
authenticates, encodes commands, decodes envelopes, and reports lifecycle. It
does not know that `message.created` means anything.

`features/<feature>/realtime/` interprets events for one feature and persists
them. It does not own connection, reconnection or authentication.

### Guarantees the handler owns

1. **Deduplication.** Every event carrying an `eventId` is registered in
   `processed_events` before being applied. A reconnect replays facts the client
   already holds; applying one twice double-counts an unread badge.
2. **Ordering.** `occurredAt` is passed to the write, which refuses to overwrite
   a row holding a newer stamp. A late broadcast cannot undo newer state.
3. **Isolation.** A malformed frame is logged and dropped. It never kills the
   subscription.
4. **Silence.** Payload contents are never logged — they are customer messages.

### Connection state versus synchronisation state

These are tracked separately and must never be conflated.

- `SocketConnectionState` — disconnected / connecting / connected /
  reconnecting / unauthenticated. About a TCP connection.
- `SyncPhase` — idle / syncing / synchronized / stale / failed. About whether
  this device has caught up.

A client can be connected and stale (just reconnected, catch-up not yet run) or
disconnected and current (synced a second before the tunnel). Showing a green
dot for the first case is the bug this separation prevents.

---

## 8. Offline-first architecture

### Reads

`watchConversations` and `watchMessages` read the database and **cannot** make a
network call — the interfaces give the caller no way to. Synchronisation is a
separate verb, called by a coordinator, never implied by opening a screen.

### Writes — the outbox

```
UI → Controller → MessageService (rules) → MessageRepository
   → [message row + outbox entry, ONE transaction]
   → OutboxCoordinator.drain
   → socket command (idempotency key = outbox id)
   → server acknowledgement
   → re-key the optimistic row to the server id
   → reactive query → UI
```

The message is durable **before** it is sent. The app can be killed between the
tap and the acknowledgement without losing what the user wrote.

Properties, each tested:

- **Idempotency.** `clientMessageId` is generated once and reused on every
  retry, so a resend after a lost acknowledgement returns the original message
  instead of creating a duplicate. The server reports `deduplicated: true`.
- **Atomic claim.** `OutboxDao.claim` updates only rows still `pending`, so two
  concurrent drains cannot both send one command.
- **Backoff.** Retryable failures requeue with exponential backoff and full
  jitter, capped. Jitter is not decoration: without it every client that lost
  one server restart resends in the same instant.
- **Terminal rejections.** `VALIDATION_FAILED`, `FORBIDDEN`, `NOT_FOUND` and
  `CONFLICT` fail immediately — the server will repeat them.
- **Attempt cap.** After `maxAttempts` an entry stops retrying, stays visible,
  and offers a manual retry. A dropped mutation the user never hears about is
  worse than a visible failure.
- **Crash recovery.** Entries left `inFlight` return to `pending` at start-up.
  The command may or may not have reached the server, which is exactly what the
  idempotency key covers.

### Synchronisation

- **First sync** — no cursor: pull a page of the rail.
- **Incremental** — `conversation:sync` with the stored `since`. The server
  returns the current state of affected rows rather than an event replay:
  smaller after a long absence, and impossible to apply out of order.
- **Reconnect** — catch up, then recover and drain the outbox.

The cursor advances **only** on a confirmed success, using the server's own
`syncedAt` — never the device clock, which may be minutes fast. A failed pass
leaves the cursor alone so the next attempt re-requests the same window.
Advancing past an unconfirmed window is how a client silently skips a day of
messages.

---

## 9. Error model

`lib/failures/app_failure.dart` defines one sealed hierarchy:
`ValidationFailure`, `AuthenticationFailure`, `AuthorizationFailure`,
`NotFoundFailure`, `ConflictFailure`, `TransportFailure`, `SocketFailure`,
`DatabaseFailure`, `SynchronizationFailure`, `UnknownFailure`.

**Infrastructure exception types never escape the data layer.** `HttpException`
and `SocketException` are confined to `infrastructure/` and translated at the
data boundary — `ConversationRemoteDataSource._send` and
`AuthRepositoryImpl` are where that happens. Rule 27 enforces it.

Presentation maps a failure to copy the user can act on. A screen never renders
an exception's `toString`.

---

## 10. State management

```
Screen → Controller → Application / Domain → Repository → Database
```

Riverpod provides screen state, async state, dependency wiring, lifecycle and
reactive exposure. It is a mechanism, not a layer: there is no `providers/`
directory, and each provider is declared beside the controller that owns it.

Controllers own screen state and actions. They hold no business rules and no
copy of the message list — the list lives in the database, and a second copy is
how an optimistic message and its acknowledged twin end up on screen together.

---

## 11. HTTP policy

HTTP is **secondary**. It is used for exactly three things:

1. **Sign-in, refresh, sign-out.** The socket handshake needs a token, and a
   token is what signing in produces — there is no connection to send
   credentials over yet.
2. **File upload and download.** Streamed bodies, not frames.
3. **Endpoints the socket genuinely does not expose.** There are none today.

A new HTTP call for anything else is an architectural decision that belongs in
this document, not a convenience.

---

## 12. Design system

`packages/tajeerai-design-system/tokens.json` is the source of truth for every
colour, type step, radius, spacing step and motion value. `lib/app/theme/`
transcribes it, and `test/app/theme/tokens_parity_test.dart` checks the
transcription against the file so the two platforms cannot drift.

Rules:

- No hardcoded colour, radius, font stack or off-scale spacing in a component.
- Both light and dark are complete and must both be verified.
- Layouts use logical directions (`start`/`end`, `EdgeInsetsDirectional`) so
  Arabic and English share one implementation.
- Generic components go in `design_system/`; business-aware widgets stay in
  their feature. `AppButton` is shared, `MessageBubble` is not.
- Extend an existing component with a variant before adding a sibling.

---

## 13. Testing rules

**No meaningful business behaviour without tests.** A change is not complete
because it compiles, analyses clean, or works when tried by hand.

| Layer | What must be tested |
| --- | --- |
| Domain | Every service, entity with behaviour, value object, rule and invariant — without Flutter, Riverpod, a database or a socket. |
| Application | Coordinators and workflows: success, validation failure, dependency failure, retry, edge cases. |
| Data | Repositories: reads, writes, mapping, failures, malformed data, empty results, duplicates. |
| Realtime | Every handler: valid, malformed, unknown, duplicate, ordering, persistence, error handling. |
| Database | Migrations, CRUD, indexes, transactions, reactive queries, offline persistence. |
| Presentation | Controllers and widgets: loading, error, empty and success states; interactions; accessibility. |
| Offline | Read offline, write offline, pending persistence, outbox, retry after reconnect, failure, acknowledgement, duplicates, sync after reconnect. |

Bug fixes are test-first: reproduce in a failing test, fix, keep the test.

Coverage is enforced by `tool/check_coverage.dart` — 80% overall, with higher
floors on domain, application, realtime, the DAOs and the failure taxonomy.
Coverage is a guardrail, not a goal; a test written only to move the number is
worse than the gap it fills.

---

## 14. Naming

| Kind | Pattern | Example |
| --- | --- | --- |
| Controller | `<Screen>Controller` | `LoginController` |
| Domain service | `<Aggregate>Service` | `ConversationService` |
| Repository contract | `<Aggregate>Repository` | `MessageRepository` |
| Repository impl | `<Aggregate>RepositoryImpl` | `MessageRepositoryImpl` |
| Coordinator | `<Workflow>Coordinator` | `OutboxCoordinator` |
| Socket handler | `<Feature>SocketHandler` | `ConversationSocketHandler` |
| Cross-feature contract | `<Thing>Capability` | `SessionCapability` |

Avoid `Manager`, `Helper`, `Utils`, `Common`, `Misc`, `GlobalService` unless the
responsibility genuinely warrants it. `SocketManager` earns its name: it manages
a connection's lifecycle and nothing else.

---

## 15. Enforcement

`tool/check_architecture.dart` implements 30 rules across five rule classes. Each
violation prints the rule, the source file and line, the forbidden dependency,
why it is wrong, and what to use instead. Non-zero exit fails CI.

```bash
dart run tool/check_architecture.dart
```

Rules are objects, not branches in a long function: adding one is adding a file
under `tool/architecture/rules/` and a line in `_fileRules`.

### The 30 rules

1–5 Presentation must not import data, infrastructure, repository
implementations, database APIs or socket infrastructure.
6–9 Domain must not import Flutter, Riverpod, infrastructure or UI.
10 Application must not import presentation.
11–12 Infrastructure must not import presentation or feature implementation.
13–15 Feature A must not import feature B's presentation, data or infrastructure.
16–18 Widgets must not use the socket or database directly; screens must not
import repositories; the design system stays business-agnostic.
19–23 `core/`, `shared/`, `presentation/providers/`, `helpers/`, `utils/` are
forbidden.
24 Application must not become a global business-logic layer.
25 Domain services stay free of infrastructure.
26 Raw realtime payload types must not reach presentation.
27 Infrastructure exception types must not reach presentation or domain.
28 Generated code is not a bypass.
29 Relative imports resolve to the same paths as `package:` imports, so a
boundary cannot be evaded by switching import style.
30 Every future feature is checked by the same rules, with no edit.

---

## 16. Backend assumptions

Recorded here because they are load-bearing and were derived from the backend
source, not invented.

1. **Auth is cookie-based.** `POST /v1/auth/login` returns `{user, tenant}` and
   sets `tj_access` / `tj_refresh` as httpOnly cookies. The client captures the
   exchange in a Dio cookie jar and reads the access token's value back out to
   hand to the socket handshake, which accepts `handshake.auth.token`
   (`SocketAuthService.extractToken`). **This needs no server change.** If the
   backend later returns tokens in the body for non-browser clients,
   `AuthRemoteDataSource` is the only file that changes.

2. **The socket is Socket.IO**, not a raw WebSocket. Its handshake, rooms and
   acknowledgement callbacks are protocol, not a library preference.

3. **Every broadcast carries `eventId` and `occurredAt`**
   (`SocketEventEnvelope`). Deduplication and ordering depend on this.

4. **`conversation:sync` returns current rows, not an event replay**, and its
   `syncedAt` is the next cursor.

5. **`message:send` is idempotent on `clientMessageId`** and reports
   `deduplicated`.

6. **The API and the socket share one origin.** The gateway is served by the
   Nest application.

7. **`conversation:list` acknowledges a cursor-paginated page.** The client
   reads `items` / `data`, `nextCursor` and `hasMore`; if the server names the
   array differently, `ConversationRemoteDataSource._decodeConversations` is the
   single place to adjust.

---

## 17. Remaining work

Recorded so they are decisions, not omissions.

- **Socket.IO integration test.** `socket_connection.dart` is excluded from
  coverage because exercising it needs a live Socket.IO server; a unit test
  could only assert against a mock of the library. Everything built on it is
  tested through the `SocketClient` interface with a fake transport. An
  integration test against a running backend would close this.
- **`custom_lint` / `riverpod_lint`** are not installed: they pin an older
  analyzer than `riverpod_generator` 4.x requires. Revisit when that resolves.
- **Bundled fonts.** `IBM Plex Sans Arabic` is requested by name with a fallback
  stack; the face is not yet shipped as an asset.
- **Push notifications.** `infrastructure/notifications/` is intentionally
  empty — no provider has been chosen, and an empty abstraction would be a
  guess.
- **Media download and attachment rendering.** `FileStorage` provides the
  location; the flow is not built.
- **Localization.** `AppStrings` is a plain map with the shape `gen-l10n`
  produces. Moving to ARB is mechanical when the copy volume justifies it.
