/// Which way a call is travelling.
enum CallDirection {
  incoming,
  outgoing;

  bool get isIncoming => this == CallDirection.incoming;

  bool get isOutgoing => this == CallDirection.outgoing;
}
