import 'dart:async';

import '../../../../failures/app_failure.dart';
import '../../../../infrastructure/logging/logger.dart';
import '../../data/remote/conversation_remote_data_source.dart';

/// Keeps the member's seat in the threads they have open.
///
/// **The piece that makes an open thread live.** The server broadcasts a new
/// message to everyone allowed to hear about the conversation, but it
/// broadcasts every *change* to one that already exists -- a delivery tick, an
/// attachment finishing its upload, a message being taken back, the customer
/// starting to type -- to the conversation's own room and nowhere else. A
/// client that never takes a seat in that room shows a thread that looks
/// alive, because messages still arrive, and is silently missing all of it.
///
/// The seat has a second job the UI cannot see: the server skips pushing a
/// notification to a member it can tell is already looking at the thread.
///
/// ## Why it rejoins on every connection
///
/// A room is socket state, not account state. A dropped connection tears it
/// down, and the reconnect comes back with the rooms the member's *grants*
/// give them -- which does not include the conversation they happen to be
/// reading. Joining only when a screen opens leaves every thread that survived
/// a tunnel or a lock screen permanently half-live, and nothing about it looks
/// broken. So the joined set is remembered and replayed on each connection.
///
/// ## Why a set and not one id
///
/// The web Inbox has exactly one conversation open at a time. A phone stacks
/// routes: a thread, a customer, a second thread. Each screen enters and
/// leaves on its own, and until the last one has left there is still somebody
/// reading.
class ConversationPresenceCoordinator {
  ConversationPresenceCoordinator({
    required ConversationRemoteDataSource remote,
    required Logger logger,
  }) : _remote = remote,
       _logger = logger;

  final ConversationRemoteDataSource _remote;
  final Logger _logger;

  final Set<String> _occupied = <String>{};

  StreamSubscription<void>? _connections;

  /// The threads currently held open. For the coordinator's tests.
  Set<String> get occupied => Set<String>.unmodifiable(_occupied);

  /// Wires the coordinator to the connection's lifecycle.
  ///
  /// [connections] fires on every successful (re)connection; each one is a
  /// fresh socket with none of the previous one's rooms.
  void bindTo(Stream<void> connections) {
    _connections ??= connections.listen((_) => unawaited(_rejoinAll()));
  }

  /// Takes a seat in [conversationId].
  ///
  /// Recorded before the command is sent, so a join that fails is still
  /// replayed on the next connection rather than forgotten -- which is the
  /// case that matters, because the usual reason it failed is that the
  /// connection was already going.
  Future<void> enter(String conversationId) async {
    _occupied.add(conversationId);

    await _join(conversationId);
  }

  /// Gives the seat up.
  ///
  /// Forgotten locally whatever the server says: the member has left the
  /// screen, and a `leave` that did not arrive costs nothing beyond a few
  /// frames the client ignores. The room goes with the socket in any case.
  Future<void> leave(String conversationId) async {
    if (!_occupied.remove(conversationId)) return;

    try {
      await _remote.leaveConversation(conversationId);
    } on AppFailure catch (failure) {
      _logger.debug(
        'conversation seat not released',
        data: <String, Object?>{'reason': failure.runtimeType.toString()},
      );
    }
  }

  Future<void> _rejoinAll() async {
    for (final String conversationId in _occupied.toList()) {
      await _join(conversationId);
    }
  }

  /// Joins, and never throws.
  ///
  /// A failure here is not worth a sentence on screen: the thread still shows
  /// everything the device holds and everything that arrives on the inbox
  /// audience, and the next connection retries. Reporting it would put an
  /// error in front of a member who has nothing to do about it.
  Future<void> _join(String conversationId) async {
    try {
      await _remote.joinConversation(conversationId);
    } on AppFailure catch (failure) {
      _logger.warning(
        'could not take a seat in the conversation',
        data: <String, Object?>{'reason': failure.runtimeType.toString()},
      );
    }
  }

  Future<void> dispose() async {
    await _connections?.cancel();
    _connections = null;
    _occupied.clear();
  }
}
