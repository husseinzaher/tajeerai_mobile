import 'dart:async';

import 'socket_command.dart';
import 'socket_event.dart';

/// The transport contract.
///
/// An interface because the socket is the one dependency that makes a test
/// need a running server otherwise. Every synchronisation and outbox test in
/// this project drives a fake implementation of exactly this, which is only
/// possible because nothing above it names Socket.IO.
abstract interface class SocketClient {
  /// Opens the connection with [token] on the handshake.
  Future<void> connect({required String token});

  /// Closes it. Idempotent.
  Future<void> disconnect();

  /// Every frame the server pushes, already decoded into [SocketEvent].
  Stream<SocketEvent> get events;

  /// Transport-level lifecycle signals -- connected, disconnected, errors.
  Stream<SocketLifecycle> get lifecycle;

  /// Sends [command] and waits for its acknowledgement.
  ///
  /// Throws [SocketException] on timeout, on a closed connection, or when the
  /// server rejects it. Callers do not poll: the ack is the reply.
  Future<SocketAckSuccess> send(SocketCommand command, {Duration? timeout});

  /// Sends without waiting for an acknowledgement.
  ///
  /// Only for genuinely transient signals -- typing is the one the backend
  /// broadcasts straight from its gateway. Anything that changes stored state
  /// uses [send], so a lost frame is detectable.
  void emit(SocketCommand command);

  bool get isConnected;

  Future<void> dispose();
}

/// A transport-level occurrence, distinct from a business event.
sealed class SocketLifecycle {
  const SocketLifecycle();
}

final class SocketConnected extends SocketLifecycle {
  const SocketConnected();
}

/// The socket closed. [wasClean] separates a deliberate close from a drop, so
/// the manager knows whether to start reconnecting.
final class SocketDisconnected extends SocketLifecycle {
  const SocketDisconnected({this.reason, this.wasClean = false});

  final String? reason;
  final bool wasClean;
}

/// The server rejected the credential.
///
/// The backend emits `auth.expired` immediately before closing precisely so a
/// client can tell this apart from a dead network -- without it the client
/// reconnects forever into the same rejection.
final class SocketAuthenticationRejected extends SocketLifecycle {
  const SocketAuthenticationRejected({this.reason});

  final String? reason;
}

/// The member's permissions changed and the server dropped the socket so it
/// comes back with the rooms their current grants allow. The client must
/// resynchronise rather than assume what it holds is still complete.
final class SocketAccessChanged extends SocketLifecycle {
  const SocketAccessChanged();
}

final class SocketTransportError extends SocketLifecycle {
  const SocketTransportError(this.error);

  final Object error;
}
