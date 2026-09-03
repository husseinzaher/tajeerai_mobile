import 'dart:async';

import 'package:tajeerai_mobile/infrastructure/realtime/authentication/socket_credentials.dart';
import 'package:tajeerai_mobile/infrastructure/realtime/socket_client.dart';
import 'package:tajeerai_mobile/infrastructure/realtime/socket_command.dart';
import 'package:tajeerai_mobile/infrastructure/realtime/socket_event.dart';
import 'package:tajeerai_mobile/infrastructure/realtime/socket_exception.dart';

/// A [SocketClient] with no socket.
///
/// Every reconnection, credential-refresh and command test in this project
/// drives this. That is only possible because nothing above `SocketClient`
/// names Socket.IO -- which is the reason the interface exists.
class FakeSocketClient implements SocketClient {
  final StreamController<SocketEvent> _events =
      StreamController<SocketEvent>.broadcast();
  final StreamController<SocketLifecycle> _lifecycle =
      StreamController<SocketLifecycle>.broadcast();

  final List<String> connectTokens = <String>[];
  final List<SocketCommand> sentCommands = <SocketCommand>[];
  final List<SocketCommand> emittedCommands = <SocketCommand>[];

  int disconnectCalls = 0;
  bool _connected = false;

  /// Thrown by the next [connect]. Cleared after it fires once, so a test can
  /// make one attempt fail and the next succeed.
  Object? connectFailure;

  /// Answers the next [send].
  SocketAckSuccess? nextAck;
  Object? sendFailure;

  @override
  Stream<SocketEvent> get events => _events.stream;

  @override
  Stream<SocketLifecycle> get lifecycle => _lifecycle.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect({required String token}) async {
    connectTokens.add(token);

    final failure = connectFailure;

    if (failure != null) {
      connectFailure = null;

      throw failure;
    }

    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    _connected = false;
  }

  @override
  Future<SocketAckSuccess> send(
    SocketCommand command, {
    Duration? timeout,
  }) async {
    sentCommands.add(command);

    final failure = sendFailure;

    if (failure != null) throw failure;

    if (!_connected) throw SocketException.disconnected(command.name);

    return nextAck ?? const SocketAckSuccess(<String, Object?>{});
  }

  @override
  void emit(SocketCommand command) => emittedCommands.add(command);

  @override
  Future<void> dispose() async {
    await _events.close();
    await _lifecycle.close();
  }

  // -- Test drivers ------------------------------------------------------

  /// Simulates the server pushing a frame.
  void pushEvent(SocketEvent event) => _events.add(event);

  /// Simulates the connection dropping.
  void drop({bool wasClean = false, String? reason}) {
    _connected = false;
    _lifecycle.add(SocketDisconnected(reason: reason, wasClean: wasClean));
  }

  /// Simulates the server rejecting the credential, which it sends
  /// immediately before closing the socket.
  void rejectCredential({String reason = 'unauthenticated'}) {
    _connected = false;
    _lifecycle.add(SocketAuthenticationRejected(reason: reason));
  }

  void changeAccess() => _lifecycle.add(const SocketAccessChanged());

  void reportError(Object error) => _lifecycle.add(SocketTransportError(error));
}

/// A credentials provider whose answers a test controls.
class FakeCredentials implements SocketCredentialsProvider {
  FakeCredentials({this.token = 'token-1', this.refreshed = 'token-2'});

  /// The current token, or null for "no session".
  String? token;

  /// What a refresh returns, or null when the session cannot be recovered.
  String? refreshed;

  int currentCalls = 0;
  int refreshCalls = 0;

  @override
  Future<String?> currentToken() async {
    currentCalls += 1;

    return token;
  }

  @override
  Future<String?> refreshToken() async {
    refreshCalls += 1;
    token = refreshed;

    return refreshed;
  }
}
