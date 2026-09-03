import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the device believes it has a network path.
enum NetworkStatus { online, offline }

/// Reports network reachability changes.
///
/// Deliberately a *hint*, not the truth. The OS reporting a Wi-Fi association
/// does not mean the server is reachable -- a captive portal reports online
/// and answers nothing -- so nothing in the app treats this as proof of
/// connectivity. The socket's own connection state is the authority; this
/// exists to stop retry loops burning battery while the radio is plainly off,
/// and to trigger a reconnect attempt the moment a path reappears.
class ConnectivityMonitor {
  ConnectivityMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Stream<NetworkStatus> get changes =>
      _connectivity.onConnectivityChanged.map(_statusOf).distinct();

  Future<NetworkStatus> current() async =>
      _statusOf(await _connectivity.checkConnectivity());

  static NetworkStatus _statusOf(List<ConnectivityResult> results) {
    final hasPath = results.any((result) => result != ConnectivityResult.none);

    return hasPath ? NetworkStatus.online : NetworkStatus.offline;
  }
}
