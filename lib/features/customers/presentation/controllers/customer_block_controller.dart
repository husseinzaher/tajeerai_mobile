import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../../../failures/app_failure.dart';

part 'customer_block_controller.g.dart';

/// What the last block or unblock came to -- a reason the screen words.
enum CustomerBlockOutcome {
  blocked,
  unblocked,

  /// Online only, and there was no connection. Nothing changed.
  needsConnection,

  /// The member may not change this contact.
  notAllowed,

  /// Anything else.
  failed,
}

/// The block action's state.
final class CustomerBlockState {
  const CustomerBlockState({this.isWorking = false, this.outcome});

  final bool isWorking;

  /// The last thing worth telling the member, consumed by the screen.
  final CustomerBlockOutcome? outcome;

  @override
  bool operator ==(Object other) =>
      other is CustomerBlockState &&
      other.isWorking == isWorking &&
      other.outcome == outcome;

  @override
  int get hashCode => Object.hash(isWorking, outcome);
}

/// Blocks and unblocks one contact.
///
/// **Online only**, like writing a note: the server is what drops a blocked
/// contact's messages and refuses sends to them, so a block queued on a phone
/// would be a block that is not happening. The repository writes the server's
/// answer locally, so the screen -- and the Inbox's customer panel -- redraw
/// from the database rather than from anything this holds.
@riverpod
class CustomerBlockController extends _$CustomerBlockController {
  @override
  CustomerBlockState build(String customerId) => const CustomerBlockState();

  Future<void> block() => _run(blocking: true);

  Future<void> unblock() => _run(blocking: false);

  Future<void> _run({required bool blocking}) async {
    if (state.isWorking) return;

    state = const CustomerBlockState(isWorking: true);

    CustomerBlockOutcome outcome;

    try {
      final customers = ref.read(customerRepositoryProvider);

      if (blocking) {
        await customers.block(customerId);
      } else {
        await customers.unblock(customerId);
      }

      outcome = blocking
          ? CustomerBlockOutcome.blocked
          : CustomerBlockOutcome.unblocked;
    } on AppFailure catch (failure) {
      outcome = switch (failure) {
        TransportFailure(isOffline: true) =>
          CustomerBlockOutcome.needsConnection,
        AuthorizationFailure() => CustomerBlockOutcome.notAllowed,
        _ => CustomerBlockOutcome.failed,
      };
    }

    // The screen may have closed while the server answered.
    if (!ref.mounted) return;

    state = CustomerBlockState(outcome: outcome);
  }

  void clearOutcome() {
    if (state.outcome == null) return;

    state = CustomerBlockState(isWorking: state.isWorking);
  }
}
