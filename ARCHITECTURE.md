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
│   ├── theme/                 Generated from design/tokens.json, plus the accessors and the preset lookup.
│   ├── shell/                 The signed-in frame: the design system's AppShell joined to the session and the routes.
│   └── localization/          Locale selection and copy.
│
├── design_system/             Business-agnostic UI. Imports no feature: a conversation reaches it as presentation data.
│   ├── design_system.dart     The barrel. The only door a feature may use.
│   ├── primitives/ buttons/ inputs/ display/ cards/ feedback/ loaders/ overlays/ layouts/
│   ├── auth/                  The frame and the parts of every unauthenticated screen.
│   ├── shell/                 The toolbar, the navigation drawer, the bottom bar and the shell that holds them.
│   ├── channels/              A channel's kind, its instance colour and what it can carry — never which feature owns it.
│   ├── inbox/                 The Inbox's row and list, drawn from AppConversationSummary rather than a domain type.
│   ├── messaging/             The thread: the timeline builder, the bubble, day and system lines, typing.
│   ├── localization/          The copy components render on their own behalf.
│   └── showcase/              The debug-only gallery. The same components, never copies.
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
signed-in user's id. It depends on
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
3. **Workspace data the socket does not expose** — customers, orders and
   products, and a note appended to a customer. The backend has no socket
   commands for those modules, and adding a transport to it for a few read
   screens would be a larger change than the screens. They sync into the local
   database like everything else, so the screens still read offline.

A new HTTP call for anything else is an architectural decision that belongs in
this document, not a convenience.

**RULE 36** keeps every call where that decision can be reviewed. `HttpClient`
is imported only by a feature's `data/remote/` sources, the network layer and
the composition root, and nothing outside `infrastructure/network/` names Dio
or a cookie jar. Which endpoint a data source calls is still a question for
review; the guard makes sure every call sits where the review looks.

A 401 renews the session once, through the same single-flight renewal the socket
uses, and repeats the request. It has to be shared: the backend's refresh tokens
are single-use (`JwtTokenIssuer.rotate()` revokes one as it issues the next), so
two transports renewing on their own would sign members out. Only the server
refusing the refresh token ends a session; being offline, throttled or answered
with a server error does not.

---

## 12. Design system

`design/tokens.json` is the source of truth for every colour, type step,
radius, spacing step, elevation and motion value. `tool/build_tokens.dart`
generates `lib/app/theme/tokens.g.dart` from it; nothing is transcribed by hand.

It is deliberately **not** `packages/tajeerai-design-system/tokens.json`. This
client used to hand-copy the web palette, with a parity test binding the two —
a test that read a path a submodule checkout does not have, so CI skipped it
while it failed on every developer's machine. Mobile and web are two design
systems that share a brand. `tokens_completeness_test.dart` and
`contrast_test.dart` walk the mobile token file itself, so a token added there
and never emitted fails the build rather than going unnoticed.

Rules:

- No hardcoded colour, radius, font stack or off-scale spacing in a component —
  and outside the design system and the theme, none anywhere (RULE 34).
- Outside the design system, never build a Material widget it already wraps
  (RULE 35). A capability the component lacks is added to the component.
- Both light and dark are complete and must both be verified.
- Layouts use logical directions (`start`/`end`, `EdgeInsetsDirectional`) so
  Arabic and English share one implementation.
- Generic components go in `design_system/`; business-aware widgets stay in
  their feature. `AppButton` and `AppMessageBubble` are shared; what a
  conversation or a message *is* stays in the feature.
- Every widget carries the `App` prefix. Not taste: `Card`, `Divider`,
  `Switch`, `Checkbox`, `Radio`, `Badge`, `Chip`, `Dialog`, `Banner`, `Drawer`,
  `Tooltip` and `ListTile` all collide with `material.dart`, which every one of
  these files imports. A "prefix only when it collides" rule is what produced
  the inconsistency this replaced.
- Extend an existing component with a variant before adding a sibling.

---

### The theme is two presets, not one palette

`design/tokens.json` carries `aurora` and `tajeer`. Both declare the same 38
semantic names, and that is the whole mechanism: a component asks for
`colors.surface` and the preset decides what that is, so one component set
renders under every identity without naming one. Type, spacing, radii, motion
and channel identity live at the file's root, shared — a preset that could
carry its own spacing scale would be a second design system wearing the first
one's name, and `tokens_completeness_test.dart` asserts it cannot.

Adding a preset is adding a block to the token file. The enum, the palettes and
the lookup are generated from it, so nothing has to be remembered.

### Design System First

**Any mobile UI task starts in `lib/design_system/`.** In order:

1. Inspect what is there. Reuse the component.
2. If it nearly fits, extend it — a variant, a size, a slot.
3. If the missing pattern is reusable, build it **in the design system**, with
   both appearances, both directions and its states, and use it from there.
4. Only a genuinely feature-specific thing is built inside a feature.

A feature must never hold UI that belongs to the system. `LoginButton`,
`InboxCard` and `ConversationInput` are the shapes this forbids.

**The web design system is not a source of truth for mobile.** It cannot be
imported — it is TypeScript, and not in `pubspec.yaml` — so this is a rule
about *copying*: taking a web component's dimensions, spacing, interaction
model or touch targets instead of designing for a phone. A popover is a bottom
sheet here; a 36px control is below the touch-target floor. Enforced by review,
because no guard can see it.

### The barrel, and who may use it

- A **feature** imports `design_system/design_system.dart` and nothing else
  from the design system (RULE 31).
- A **design-system file** imports its siblings by relative path, never the
  barrel: a barrel that imports itself is a cycle, and it would make every
  component's analysis depend on every other's.
- A **test** imports the leaf file it is testing, so a unit test that renders
  nothing does not drag the whole system into its coverage record.

Coverage is measured per *loaded* library, and features import the barrel — so
a feature's widget test loads every component regardless. Introducing the
barrel moved overall coverage from 87.2% to 82.9% against an 80% floor, because
~150 component lines that had no lcov record before now have one. **A component
added to the design system is counted from the day it lands, tested or not.**
Plan for it: components and their tests land together, or the gate fails on the
next one.

### The shell, and who owns the toolbar

`AppShell` is the frame around the signed-in app: the navigation drawer, and the
bottom bar once there are two destinations. **It does not draw the toolbar.**
Each screen passes its own to `AppScaffold(toolbar:)`, because the toolbar is
the part that changes from screen to screen — a search mode on one, a
conversation header on another, a selection count on a third — and a shell that
drew it would have to know every screen.

The two meet through `AppShellScope`, which carries one fact and one callback:
whether there is a drawer, and how to open it. An `AppToolbar` inside a shell
with a drawer shows the menu button on its own. No screen wires it.

- `AppToolbar` is **one widget with a mode** — `normal`, `search`,
  `selection` — and the conversation header is its `AppToolbar.conversation`
  preset, not a fourth toolbar. Its back chevron points toward the start of the
  line, so it mirrors in Arabic; Material's `BackButton` does that for free, a
  custom toolbar does not.
- `AppNavigationDrawer` is placed as a `Scaffold.drawer`, which opens from the
  start edge — the right, in Arabic. A test asserts the edge rather than
  trusting it.
- `AppBottomNavigation` takes two to five destinations and asserts it.
  `AppShell` draws no bar below two: a tab bar with one tab is a label.
- The current destination is marked by tint, weight and the selected semantics
  flag together — never by colour alone.

`app/shell/authenticated_shell.dart` joins the shell to the session and the
routes. That is composition, which is why it lives in `app/` rather than in a
feature. It mounts **only destinations that exist** — today the Inbox, and
signing out — and no bottom bar: a drawer entry for a screen that is not built
is a control that goes nowhere. A conversation thread is pushed onto the root
navigator, so it covers the shell instead of opening inside it with the drawer
still reachable behind.

`AppScaffold` keeps its older `title`/`actions`/`leading`/`showBack` bar until
the conversation screen moves onto `AppToolbar.conversation`, and loses it
then. A scaffold with two ways to draw a title is how the next inconsistency
starts.

### Channels: which kind, which one, and what it can carry

Three facts about a channel that are easy to blur into one, kept apart in
`design_system/channels/`:

- **Which kind** — `AppChannelKind`, drawn by `AppChannelGlyph` in the named
  identity colours from `design/tokens.json` (`context.channels`). WhatsApp is
  green in every preset. Six kinds, not the backend's seven types: the two
  WhatsApp transports are one identity to a member.
- **Which one of several** — the instance colour. The server resolves it: a
  merchant's choice, or `CHANNEL_COLOR_PALETTE` hashed by channel id.
  `AppChannelPalette` mirrors that list and that hash exactly, for a channel the
  device knows only by id, and its test pins the same ids to the same slots as
  the backend's spec. It is **not a token** — the backend decides it, in
  `backend/src/modules/channel/contracts/channel-color.ts`, and the two change
  together. No instance colour is a status or accent colour on either platform;
  the backend spec lists the ones that are taken.
- **What it can carry** — `AppChannelCapabilities`, one flag per backend
  capability. A composer branches on these and never on the kind, so an SMS
  thread gets a text-only composer with no `if (sms)` in it.

`AppChannelBadge` names a channel on one line and **never draws its text in the
channel colour**: most instance colours are below 4.5:1 as text on one theme or
the other. The colour travels in the dot, and in a tint the badge's own test
holds to body-text contrast for every colour, preset and theme.

Nothing in `features/` draws these yet — `Conversation` carries only a
`channelId`. Mapping the backend's channel types onto the six kinds belongs to
the feature that first needs it.

### Presentation data, and who maps into it

The design system draws conversations without knowing what a `Conversation`
is. RULE 18 forbids the import, and a row has no use for the rules behind it
anyway. So the design system owns plain presentation types and the feature
owns the mapping into them:

| The design system draws | The feature maps, in `presentation/widgets/` |
| --- | --- |
| `AppConversationSummary` | `conversation_view_data.dart` — `Conversation.toSummary` |
| `AppConnectionStatus` | `conversation_view_data.dart` — `ConversationSyncState.connectionStatus` |
| `AppViewState<T>` | `async_view_state.dart` — `AsyncValue.toViewState` |
| `AppMessageData` | `message_view_data.dart` — `Message.toMessageData` |

The mapper is where fallbacks are decided and translated. A row's title is the
customer's name, then the thread's subject, then the app's "Unknown customer"
in the reader's language — not the domain's `displayName`, whose English last
resort is for logs. The async adapter is where offline-first shows on screen:
a value present in any state is drawn as loaded, so a refresh that is running,
or one that failed, never replaces rows with a spinner.

A screen built this way is composition. `conversation_list_screen.dart` holds
no row, no skeleton, no banner and no four-state `.when`. The row it used to
draw coloured its timestamp with the brand yellow at 1.53:1 — the kind of
decision a feature should not be in a position to make.

### The thread

A thread is drawn in three layers, each testable without the one above it.

- `AppTimelineBuilder.build` is pure Dart. It turns messages, oldest first, into
  day headings, the unread marker and runs: one author, one side, within five
  minutes, never across midnight, never including a system line.
- `AppMessageBubble` draws one message and owns the tail — the speaker's bottom
  corner is tightened, and so is the join inside a run — in logical corners, so
  Arabic mirrors without a second layout. That corner logic moved across from
  the feature's old bubble unchanged.
- `AppMessageTimeline` draws the list, reversed so it opens on the newest
  message, in the same four states as every other list.

The domain's `MessageState` serves the outbox; `AppMessageStatus` decides a
glyph. `message_view_data.dart` is the only place one becomes the other, and its
test walks every state, so a state added to the domain fails a test before it
draws as the wrong thing.

Two parts are built and have nothing to show yet: inbound typing, which no
event carries, and the unread marker, which needs a read position the device
does not keep — the count is cleared as the thread opens.

### Composing, and what the design system will not own

`AppComposer` decides its controls from `AppChannelCapabilities`, never from a
channel's name: the paperclip needs a channel that carries files *and* an app
that can pick one, the microphone a channel that carries voice *and* an app
that can record, the reply strip a channel that takes replies. `onSend` returns
whether the app took the message, and only a yes empties the field — an offline
failure never costs a member what they typed. The screen owns the
`AppComposerController`, so a reply started from a long press or a file added
from a picker reaches the composer without either reaching into it.

Three things the design system draws and deliberately does not do:

- **Play audio.** `AppAudioMessage` takes an `AppAudioController`, an interface
  the app implements over whichever player it chooses. Without one, a voice note
  is drawn and cannot play.
- **Open files or pictures.** Previews report a tap; opening is the app's, so
  the design system never learns the router.
- **Record.** `AppVoiceRecordButton` reports hold, release and slide-to-cancel,
  with a tap alternative for a screen reader that cannot hold.

The thread screen wires what the send path can carry today — text, plus copy,
retry and discard from the long-press menu. Attachments, voice notes, replies,
reactions and quick replies are built and shown in the showcase, and appear in
the screen when the send path and the data behind them exist.

The composer's failures reach the screen as a `ComposerError` reason, and the
screen words it. A controller holding sentences put English on Arabic screens.

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

### Goldens

Pixel comparisons are few on purpose, and each one is meant to be looked at.

- `test/design_system/showcase/showcase_goldens_test.dart` captures every
  showcase section **whole**, every example top to bottom. A phone-sized
  capture of a scrolling page holds its first screenful and nothing else.
- Every golden comes in two variants, not four: `ltr_light` (English, left to
  right, light) and `rtl_dark` (Arabic, right to left, dark). Between them they
  hold both directions and both appearances. The cross-product doubles the
  images and adds almost nothing a reviewer would catch.
- The product preset, plus Foundations under `aurora`. A component that reads
  tokens is right under any preset that declares them, and the palette page is
  where a preset's tokens are all on screen at once.
- The sign-in screen and the searchable select's open sheet have their own,
  because no showcase page shows either.

They carry the `golden` tag. `make golden-update` regenerates them, and a
regenerated image is a design change: look at every one that moved, and commit
it with the change that moved it. A machine that cannot reproduce the reference
rendering runs `flutter test --exclude-tags golden` rather than blessing a
diff.

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

`tool/check_architecture.dart` implements 36 rules across eight rule files. Each
violation prints the rule, the source file and line, the forbidden dependency,
why it is wrong, and what to use instead. Non-zero exit fails CI.

```bash
dart run tool/check_architecture.dart
```

Rules are objects, not branches in a long function: adding one is adding a file
under `tool/architecture/rules/` and a line in `_fileRules`.

### The 36 rules

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
31 A feature reaches the design system only through `design_system.dart`.
32 The design system may import `app/theme/`, and nothing else under `app/`.
33 The design system must not import a state-management, routing, networking
or storage package.
34 Outside the design system and the theme: no raw colour, no font size or
family, and no number where a radius or spacing token belongs.
35 Outside the design system and the theme: no Material widget the design
system already wraps, and none of the functions that open one.
36 HTTP is reached only from a feature's `data/remote/`, the network layer and
the composition root; only the network layer names Dio or a cookie jar.

Rules 31–33 close holes rule 18 left open: it checked only that a design-system
file did not import a *feature*, so `app/bootstrap/dependencies.dart`, the
router, Riverpod and even Dio were all reachable from a component.

Rules 34 and 35 are a weaker kind of check, and that is written down rather
than left for somebody to discover. Every other rule reads resolved imports.
These read source text, with comments and string contents blanked by
`tool/architecture/source_text.dart`, and match shapes. They see through a
prefixed import, type arguments and a named constructor; a local constant
(`const gap = 16;`), a tear-off or a typedef walks past them. They were switched
on against a tree that already passed, so they carry no allowlist, and adding
one is not how a violation gets past them.

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

6. **The API and the socket are separate hosts in production** —
   `api.tajeerai.com` and `socket.tajeerai.com`. Staging serves both roles from
   one host (`staging.tajeerai.com`), as does local development. They are
   therefore configured independently (`TAJEER_API_URL`, `TAJEER_SOCKET_URL`)
   and neither is derived from the other, which is what lets them be equal in
   two environments and different in the third.

   The split is safe for authentication because the client never depended on
   the API's cookies reaching the socket host: `AuthRemoteDataSource` reads the
   access token's *value* out of the cookie jar, and the handshake carries it
   as `auth.token`. A browser client would need a different arrangement.

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
- **`custom_lint` / `riverpod_lint`** are not installed: `custom_lint` caps at
  `analyzer ^8` while `riverpod_generator` 4.x requires `^13`. Rechecked after
  a full `pub upgrade --major-versions`; still unresolvable upstream. Revisit
  when `custom_lint` moves.
- **Push notifications.** `infrastructure/notifications/` is intentionally
  empty — no provider has been chosen, and an empty abstraction would be a
  guess.
- **Media download and attachment rendering.** `FileStorage` provides the
  location; the flow is not built.
- **Localization.** `AppStrings` is a plain map with the shape `gen-l10n`
  produces, read through `appStringsProvider`. Moving to ARB is mechanical when
  the copy volume justifies it. The design system's own chrome is not in it —
  that lives in `AppMessages`, and a key in both would drift. Only the sign-in
  screen reads it so far; the conversation screens still hold English literals
  until they are moved onto the design system.
- **App icons.** The logo itself is real — `AppBrandLogo` draws the official
  exports in `assets/brand/`, through copies `build_app_assets.py` trims and
  downscales into `assets/brand/app/`, the only folder the app bundles. The
  Android and iOS launcher icons are still Flutter's default, by decision,
  until the official app-icon exports exist: they are what people see on a home
  screen and in the stores, and Android needs separate foreground and
  background layers.
- **Social sign-in, "forgot password" and "create an account".** The reference
  design draws all three and the sign-in screen draws none, because nothing sits
  behind them on mobile yet — a control that goes nowhere is worse than an
  absent one. `AppSocialButton` is built and documented in the showcase for the
  day the OAuth flow exists.
