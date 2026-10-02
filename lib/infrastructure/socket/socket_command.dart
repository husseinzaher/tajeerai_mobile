/// A command sent to the server over the realtime transport.
///
/// Business-agnostic on purpose: this layer knows a command has a name, a
/// payload and an acknowledgement, and knows nothing about what
/// `conversation:list` means. The names themselves live with the feature that
/// owns them -- see `features/conversations/realtime/`.
class SocketCommand {
  const SocketCommand({
    required this.name,
    this.payload = const <String, Object?>{},
  });

  /// The server's event name, `subject:verb` (`message:send`).
  final String name;

  final Map<String, Object?> payload;

  @override
  String toString() => 'SocketCommand($name)';
}

/// The server's reply to a command.
///
/// Mirrors the backend's `SocketAck<T>` envelope --
/// `{ok: true, data} | {ok: false, error: {code, message, details}}` -- rather
/// than a bare payload, so a rejection is a value the caller must handle and
/// not an exception that happens to be thrown from a different place.
sealed class SocketAck {
  const SocketAck();

  /// Parses the wire envelope.
  ///
  /// Anything that does not match the contract is treated as a malformed
  /// failure rather than being coerced into a success -- a client that reads
  /// a broken frame as `ok` corrupts its own database.
  factory SocketAck.fromWire(Object? raw) {
    if (raw is! Map) {
      return const SocketAckFailure(
        code: 'INTERNAL_ERROR',
        message: 'Malformed acknowledgement.',
      );
    }

    if (raw['ok'] == true) {
      final data = raw['data'];

      return SocketAckSuccess(
        data is Map ? Map<String, Object?>.from(data) : <String, Object?>{},
        rawData: data,
      );
    }

    final error = raw['error'];

    if (error is! Map) {
      return const SocketAckFailure(
        code: 'INTERNAL_ERROR',
        message: 'The server rejected the command.',
      );
    }

    return SocketAckFailure(
      code: error['code']?.toString() ?? 'INTERNAL_ERROR',
      message: error['message']?.toString() ?? 'The command failed.',
      details: _detailsOf(error['details']),
    );
  }

  static Map<String, List<String>>? _detailsOf(Object? raw) {
    if (raw is! Map) return null;

    return raw.map(
      (key, value) => MapEntry(
        key.toString(),
        value is List
            ? value.map((entry) => entry.toString()).toList(growable: false)
            : <String>[value.toString()],
      ),
    );
  }
}

final class SocketAckSuccess extends SocketAck {
  const SocketAckSuccess(this.data, {this.rawData});

  /// The `data` object. Empty when the command acknowledges without a body.
  final Map<String, Object?> data;

  /// The unwrapped `data`, for the commands that acknowledge with a list
  /// rather than an object.
  final Object? rawData;
}

final class SocketAckFailure extends SocketAck {
  const SocketAckFailure({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final Map<String, List<String>>? details;
}
