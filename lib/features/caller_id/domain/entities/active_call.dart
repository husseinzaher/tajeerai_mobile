import '../value_objects/call_direction.dart';
import '../value_objects/call_status.dart';
import 'caller_identity.dart';

/// One screened call and the identity the card is showing.
final class ActiveCall {
  const ActiveCall({
    required this.callId,
    required this.phoneNumber,
    required this.direction,
    required this.status,
    this.identity,
    this.startedAt,
  });

  final String callId;
  final String phoneNumber;
  final CallDirection direction;
  final CallStatus status;
  final CallerIdentity? identity;
  final DateTime? startedAt;

  ActiveCall copyWith({
    CallStatus? status,
    CallerIdentity? identity,
    DateTime? startedAt,
  }) {
    return ActiveCall(
      callId: callId,
      phoneNumber: phoneNumber,
      direction: direction,
      status: status ?? this.status,
      identity: identity ?? this.identity,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ActiveCall &&
      other.callId == callId &&
      other.phoneNumber == phoneNumber &&
      other.direction == direction &&
      other.status == status &&
      other.identity == identity;

  @override
  int get hashCode =>
      Object.hash(callId, phoneNumber, direction, status, identity);
}
