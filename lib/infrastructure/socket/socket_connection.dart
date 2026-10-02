import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../logging/logger.dart';
import 'socket_client.dart';
import 'socket_command.dart';
import 'socket_event.dart';
import 'socket_exception.dart';
import 'serialization/event_codec.dart';

/// The Socket.IO implementation of [SocketClient].
///
/// Socket.IO rather than a raw WebSocket because the backend's gateway *is*
/// Socket.IO (`@WebSocketGateway`, `transports: ['websocket', 'polling']`) --
/// its handshake, room semantics and acknowledgement callbacks are protocol,
/// not a library preference, and a bare `WebSocket` cannot speak them.
///
/// The handshake carries `auth.token`, which the backend's `SocketAuthService`
/// accepts alongside the browser's cookie. That is what lets a mobile client
/// authenticate without a cookie jar on the socket.
///
/// This class owns exactly one connection and no policy: reconnection timing,
/// credential refresh and resynchronisation all live in [SocketManager]. Its
/// job is to turn frames into [SocketEvent]s and commands into acknowledged
/// futures.
class SocketConnection implements SocketClient {
  SocketConnection({
    required String url,
    required Logger logger,
    required Duration commandTimeout,
    EventCodec codec = const EventCodec(),
  }) : _url = url,
       _logger = logger,
       _commandTimeout = commandTimeout,
       _codec = codec;

  final String _url;
  final Logger _logger;
  final Duration _commandTimeout;
  final EventCodec _codec;

  io.Socket? _socket;

  final StreamController<SocketEvent> _events =
      StreamController<SocketEvent>.broadcast();
  final StreamController<SocketLifecycle> _lifecycle =
      StreamController<SocketLifecycle>.broadcast();

  @override
  Stream<SocketEvent> get events => _events.stream;

  @override
  Stream<SocketLifecycle> get lifecycle => _lifecycle.stream;

  @override
  bool get isConnected => _socket?.connected ?? false;

  @override
  Future<void> connect({required String token}) async {
    await disconnect();

    final socket = io.io(
      _url,
      io.OptionBuilder()
          .setTransports(<String>['websocket'])
          // Reconnection is this app's decision, not the library's: the client
          // has to refresh its token and resynchronise between attempts, and
          // Socket.IO's own loop would reconnect with the dead credential.
          .disableAutoConnect()
          .disableReconnection()
          .setAuth(<String, dynamic>{'token': token})
          .build(),
    );

    _socket = socket;
    _bind(socket);

    final connected = Completer<void>();

    void completeOnce([Object? error]) {
      if (connected.isCompleted) return;
      error == null ? connected.complete() : connected.completeError(error);
    }

    socket
      ..onConnect((_) => completeOnce())
      ..onConnectError(
        (error) => completeOnce(
          SocketException(message: 'Could not connect.', cause: error),
        ),
      );

    socket.connect();

    // A handshake that never resolves must not leave the caller awaiting
    // forever -- the manager needs the failure to schedule its backoff.
    await connected.future.timeout(
      _commandTimeout,
      onTimeout: () => throw const SocketException(
        message: 'Timed out opening the connection.',
        code: 'TIMEOUT',
      ),
    );
  }

  void _bind(io.Socket socket) {
    socket
      ..onConnect((_) {
        _logger.info('socket connected');
        _emitLifecycle(const SocketConnected());
      })
      ..onDisconnect((reason) {
        _logger.info('socket disconnected', data: {'reason': '$reason'});
        _emitLifecycle(SocketDisconnected(reason: reason?.toString()));
      })
      ..onError((error) {
        _logger.warning('socket error', data: {'error': '$error'});
        _emitLifecycle(SocketTransportError(error as Object));
      })
      // `auth.expired` and `access.changed` are transport concerns: both mean
      // "this connection is about to be closed by the server", and both need
      // handling before the frames become business events.
      ..on(EventCodec.authExpiredEvent, (data) {
        _emitLifecycle(
          SocketAuthenticationRejected(reason: _codec.reasonOf(data)),
        );
      })
      ..on(EventCodec.accessChangedEvent, (_) {
        _emitLifecycle(const SocketAccessChanged());
      })
      // Everything else is forwarded verbatim. This layer does not know which
      // names matter; the feature handlers filter.
      ..onAny((name, data) {
        if (_codec.isLifecycleEvent(name)) return;

        _emitEvent(SocketEvent.fromWire(name, data));
      });
  }

  void _emitEvent(SocketEvent event) {
    if (_events.isClosed) return;
    _events.add(event);
  }

  void _emitLifecycle(SocketLifecycle event) {
    if (_lifecycle.isClosed) return;
    _lifecycle.add(event);
  }

  @override
  Future<SocketAckSuccess> send(
    SocketCommand command, {
    Duration? timeout,
  }) async {
    final socket = _socket;

    if (socket == null || !socket.connected) {
      throw SocketException.disconnected(command.name);
    }

    final completer = Completer<Object?>();

    socket.emitWithAck(
      command.name,
      command.payload,
      ack: (Object? response) {
        if (!completer.isCompleted) completer.complete(response);
      },
    );

    _logger.debug('-> ${command.name}');

    final raw = await completer.future.timeout(
      timeout ?? _commandTimeout,
      onTimeout: () => throw SocketException.timeout(command.name),
    );

    final ack = SocketAck.fromWire(raw);

    return switch (ack) {
      SocketAckSuccess() => ack,
      SocketAckFailure(:final code, :final message, :final details) =>
        throw SocketException(message: message, code: code, details: details),
    };
  }

  @override
  void emit(SocketCommand command) {
    final socket = _socket;
    if (socket == null || !socket.connected) return;

    socket.emit(command.name, command.payload);
  }

  @override
  Future<void> disconnect() async {
    final socket = _socket;
    if (socket == null) return;

    _socket = null;

    socket
      ..clearListeners()
      ..dispose();
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _events.close();
    await _lifecycle.close();
  }
}
