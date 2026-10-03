import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../../../failures/app_failure.dart';
import '../../domain/entities/customer_change_proposal.dart';
import '../../domain/repositories/customer_repository.dart';

part 'customer_change_proposals_controller.g.dart';

/// The changes the AI employee proposed for one contact, from the server.
///
/// Read once per open screen and never stored -- see `CustomerChangeProposal`.
/// Fails quietly to an empty list: the section is drawn only when something is
/// pending, and offline there is nothing this device can honestly say is.
@riverpod
Future<List<CustomerChangeProposal>> customerChangeProposals(
  Ref ref,
  String customerId,
) async {
  try {
    return await ref
        .watch(customerRepositoryProvider)
        .changeProposals(customerId);
  } on AppFailure {
    return const <CustomerChangeProposal>[];
  }
}

/// What deciding a proposal came to -- a reason the screen words.
enum ChangeDecisionOutcome {
  approved,
  rejected,

  /// The server no longer has it pending: somebody decided it first.
  alreadyDecided,

  /// Online only, and there was no connection. Nothing changed.
  needsConnection,

  /// The member may not make this change -- a phone number they cannot see.
  notAllowed,

  /// Anything else.
  failed,
}

/// Which proposals are being decided, and the last outcome.
final class ChangeDecisionState {
  const ChangeDecisionState({this.deciding = const <String>{}, this.outcome});

  /// Proposal ids with a decision on its way, so their buttons wait.
  final Set<String> deciding;

  /// The last thing worth telling the member, consumed by the screen.
  final ChangeDecisionOutcome? outcome;
}

/// Approves and rejects one contact's proposed changes.
///
/// After a decision the list is read again, and after an approval the contact
/// too: approving is the server editing the contact, and the card has to show
/// the value it now holds rather than the one it held when the screen opened.
@riverpod
class CustomerChangeDecisionController
    extends _$CustomerChangeDecisionController {
  @override
  ChangeDecisionState build(String customerId) => const ChangeDecisionState();

  Future<void> approve(String proposalId) =>
      _decide(proposalId, approving: true);

  Future<void> reject(String proposalId) =>
      _decide(proposalId, approving: false);

  Future<void> _decide(String proposalId, {required bool approving}) async {
    if (state.deciding.contains(proposalId)) return;

    state = ChangeDecisionState(
      deciding: <String>{...state.deciding, proposalId},
    );

    final CustomerRepository customers = ref.read(customerRepositoryProvider);
    ChangeDecisionOutcome outcome;

    try {
      if (approving) {
        await customers.approveChange(customerId, proposalId);
        outcome = ChangeDecisionOutcome.approved;
      } else {
        await customers.rejectChange(customerId, proposalId);
        outcome = ChangeDecisionOutcome.rejected;
      }
    } on AppFailure catch (failure) {
      outcome = switch (failure) {
        NotFoundFailure() => ChangeDecisionOutcome.alreadyDecided,
        TransportFailure(isOffline: true) =>
          ChangeDecisionOutcome.needsConnection,
        AuthorizationFailure() => ChangeDecisionOutcome.notAllowed,
        _ => ChangeDecisionOutcome.failed,
      };
    }

    if (outcome == ChangeDecisionOutcome.approved) {
      try {
        await customers.refresh(customerId);
      } on AppFailure {
        // The change is applied on the server either way; the next refresh
        // brings it down.
      }
    }

    if (!ref.mounted) return;

    state = ChangeDecisionState(
      deciding: <String>{...state.deciding}..remove(proposalId),
      outcome: outcome,
    );

    // A decided proposal is no longer pending, whoever decided it.
    if (outcome == ChangeDecisionOutcome.approved ||
        outcome == ChangeDecisionOutcome.rejected ||
        outcome == ChangeDecisionOutcome.alreadyDecided) {
      ref.invalidate(customerChangeProposalsProvider(customerId));
    }
  }

  void clearOutcome() {
    if (state.outcome == null) return;

    state = ChangeDecisionState(deciding: state.deciding);
  }
}
