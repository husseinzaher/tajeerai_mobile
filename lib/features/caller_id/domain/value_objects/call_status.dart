/// Where a call is in its lifecycle.
enum CallStatus {
  ringing,
  active,
  ended;

  bool get isRinging => this == CallStatus.ringing;

  bool get isActive => this == CallStatus.active;

  bool get isEnded => this == CallStatus.ended;
}
