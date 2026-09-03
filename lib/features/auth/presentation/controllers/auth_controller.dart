import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../application/coordinators/session_coordinator.dart';
import '../../application/state/auth_state.dart';

/// Exposes the session to the presentation layer.
///
/// A thin bridge, deliberately: the state and the workflow both belong to
/// [SessionCoordinator], and duplicating either here would give the app two
/// answers to "who is signed in". This subscribes to the coordinator and
/// republishes, so the router and the app shell read one source.
///
/// Riverpod is the mechanism, not a layer. There is no `providers/` directory
/// -- this provider lives beside the controller it belongs to.
final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final coordinator = ref.watch(sessionCoordinatorProvider);

    final subscription = coordinator.states.listen((next) => state = next);
    ref.onDispose(subscription.cancel);

    return coordinator.state;
  }

  /// Resolves the session at start-up. Called once by the app shell.
  Future<void> restore() => ref.read(sessionCoordinatorProvider).restore();

  Future<void> signOut() => ref.read(sessionCoordinatorProvider).signOut();
}
