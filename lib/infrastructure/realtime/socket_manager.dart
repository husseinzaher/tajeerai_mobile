import 'dart:async';

import '../device/connectivity/connectivity_monitor.dart';
import '../logging/logger.dart';
import 'authentication/socket_credentials.dart';
import 'connection/connection_state.dart';
import 'connection/reconnect_policy.dart';
import 'socket_client.dart';
import 'socket_command.dart';
import 'socket_event.dart';
import 'socket_exception.dart';

/// Owns the connection's lifecycle.
///
/// [SocketClient] opens one socket; this decides *when* there should be one,
/// what credential it opens with, and what happens when it drops. Splitting
/// them is what keeps either from becoming the god class this layer tends
/// toward.
///
/// Responsibilities, and nothing else:
///
/// - connect when a session exists, disconnect when it ends;
/// - reconnect on a jittered backoff after an unclean drop;
/// - refresh the credential when the server rejects it, and stop -- rather
///   than loop -- when it cannot be refreshed;
/// - hold off while the device has no network path, and resume when it
///   returns;
/// - publish [SocketConnectionState] and announce each successful
///   (re)connection so interested features can resynchronise.
///
/// It interprets no business event. Frames pass through [events] untouched.
class SocketManager {
  SocketManager({
    required SocketClient client,
    required SocketCredentialsProvider credentials,
    required Logger logger,
    ConnectivityMonitor? connectivity,
    ReconnectPolicy policy = const ReconnectPolicy(),
  }) : _client = client,
       _credentials = credentials,
       _logger = logger,
       _connectivity = connectivity,
       _policy = policy;

  final SocketClient _client;
  final SocketCredentialsProvider _credentials;
  final Logger _logger;
  final ConnectivityMonitor? _connectivity;
  final ReconnectPolicy _policy;

  final StreamController<SocketConnectionState> _states =
      StreamController<SocketConnectionState>.broadcast();

  /// Fires after every successful connection, including reconnections.
  ///
  /// The signal features resynchronise on. It is emitted on the *first*
  /// connection too: a client that has been closed has missed events whether
  /// or not it was ever connected before.
  final StreamController<void> _connections =
      StreamController<void>.broadcast();

  StreamSubscription<SocketLifecycle>? _lifecycleSubscription;
  StreamSubscription<NetworkStatus>? _connectivitySubscription;
  Timer? _reconnectTimer;

  SocketConnectionState _state = SocketConnectionState.disconnected;
  int _attempt = 0;

  /// True once [start] has run: distinguishes "should be connected but isn't"
  /// from "deliberately not connected", which is what stops a reconnect loop
  /// running after sign-out.
  bool _wanted = false;

  bool _disposed = false;

  SocketConnectionState get state => _state;

  Stream<SocketConnectionState> get states => _states.stream;

  Stream<void> get connections => _connections.stream;

  /// Business frames, forwarded from the transport untouched.
  ///
  /// Feature realtime handlers subscribe here and filter by name. This class
  /// never inspects a payload.
  Stream<SocketEvent> get events => _client.events;

  /// Brings the connection up and keeps it up.
  ///
  /// Idempotent: calling it twice does not open two sockets.
  Future<void> start() async {
    if (_disposed || _wanted) return;

    _wanted = true;
    _listenToLifecycle();
    _listenToConnectivity();

    await _openConnection();
  }

  /// Takes the connection down and stops trying.
  ///
  /// Called on sign-out. Clears [_wanted] first so a drop arriving mid-teardown
  /// does not schedule a reconnection for a session that no longer exists.
  Future<void> stop() async {
    _wanted = false;
    _attempt = 0;
    _cancelReconnect();

    await _client.disconnect();
    _publish(SocketConnectionState.disconnected);
  }

  Future<void> _openConnection() async {
    if (!_wanted || _disposed) return;

    _publish(
      _attempt == 0
          ? SocketConnectionState.connecting
          : SocketConnectionState.reconnecting,
    );

    final token = await _credentials.currentToken();

    if (token == null) {
      _logger.info('no session; socket stays closed');
      _publish(SocketConnectionState.unauthenticated);

      return;
    }

    try {
      await _client.connect(token: token);

      _attempt = 0;
      _publish(SocketConnectionState.connected);

      if (!_connections.isClosed) _connections.add(null);
    } on Object catch (error) {
      _logger.warning(
        'connect failed',
        data: <String, Object?>{
          'attempt': _attempt,
          'error': error.runtimeType.toString(),
        },
      );

      _scheduleReconnect();
    }
  }

  void _listenToLifecycle() {
    _lifecycleSubscription ??= _client.lifecycle.listen((event) {
      switch (event) {
        case SocketConnected():
          _attempt = 0;
          _publish(SocketConnectionState.connected);

        case SocketDisconnected(:final wasClean):
          if (!_wanted || wasClean) {
            _publish(SocketConnectionState.disconnected);

            return;
          }

          _scheduleReconnect();

        case SocketAuthenticationRejected():
          unawaited(_recoverCredential());

        case SocketAccessChanged():
          // The server is about to drop the socket. Reconnecting recomputes
          // the rooms; the disconnect that follows triggers it.
          _logger.info('access changed; awaiting reconnect');

        case SocketTransportError():
          // Socket.IO reports errors that do not always close the connection.
          // The disconnect handler is what schedules a retry, so this only
          // records.
          break;
      }
    });
  }

  /// Handles `auth.expired`: refresh once, then reconnect with the new token.
  ///
  /// A failed refresh is terminal. Retrying a rejected credential is the loop
  /// the backend's `auth.expired` event exists to prevent, so the state
  /// becomes [SocketConnectionState.unauthenticated] and the auth feature
  /// takes over by watching for it.
  Future<void> _recoverCredential() async {
    _cancelReconnect();

    final refreshed = await _credentials.refreshToken();

    if (refreshed == null) {
      _logger.warning('session could not be refreshed; socket stopped');
      _wanted = false;
      _publish(SocketConnectionState.unauthenticated);

      return;
    }

    _attempt = 0;
    await _openConnection();
  }

  void _scheduleReconnect() {
    if (!_wanted || _disposed) return;

    _cancelReconnect();
    _publish(SocketConnectionState.reconnecting);

    _attempt += 1;
    final delay = _policy.delayFor(_attempt);

    _logger.debug(
      'reconnecting',
      data: <String, Object?>{
        'attempt': _attempt,
        'delayMs': delay.inMilliseconds,
      },
    );

    _reconnectTimer = Timer(delay, () => unawaited(_openConnection()));
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Reacts to the radio coming back.
  ///
  /// Only ever *shortens* a wait -- it never declares the socket healthy. The
  /// OS reporting a network path is not evidence the server is reachable, so
  /// the reconnection still has to succeed on its own terms.
  void _listenToConnectivity() {
    final monitor = _connectivity;
    if (monitor == null) return;

    _connectivitySubscription ??= monitor.changes.listen((status) {
      if (status != NetworkStatus.online) return;
      if (!_wanted || _state.isConnected) return;

      _logger.debug('network returned; retrying now');
      _cancelReconnect();
      unawaited(_openConnection());
    });
  }

  /// Sends a command over the live socket.
  ///
  /// Fails fast when disconnected rather than queueing: queueing is the
  /// outbox's job, and a second queue here would retry the same command twice
  /// from two places.
  Future<SocketAckSuccess> send(SocketCommand command, {Duration? timeout}) {
    if (!_state.canSend) {
      throw SocketException.disconnected(command.name);
    }

    return _client.send(command, timeout: timeout);
  }

  /// Fire-and-forget, for transient signals only. Silently dropped when the
  /// socket is down, which is correct for something like typing.
  void emit(SocketCommand command) {
    if (!_state.canSend) return;

    _client.emit(command);
  }

  void _publish(SocketConnectionState next) {
    if (_state == next) return;

    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  Future<void> dispose() async {
    _disposed = true;
    _wanted = false;
    _cancelReconnect();

    await _lifecycleSubscription?.cancel();
    await _connectivitySubscription?.cancel();
    await _client.dispose();
    await _states.close();
    await _connections.close();
  }
}
