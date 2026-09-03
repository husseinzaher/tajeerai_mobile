/// The body of an outbound text message.
///
/// A value object because "non-empty, trimmed, within the provider's limit" is
/// a business rule that the composer, the retry path and the forward path all
/// need to agree on. Expressed once, it cannot drift between them.
extension type const MessageContent._(String value) {
  /// The backend's own bound: `messageEditCommandSchema` uses
  /// `z.string().trim().min(1).max(8000)`, and the send path is the same.
  static const int maxLength = 8000;

  static MessageContentResult parse(String raw) {
    final trimmed = raw.trim();

    // An empty send is not a message: the composer must refuse it rather than
    // queue a row the server will reject.
    if (trimmed.isEmpty) {
      return const MessageContentResult.invalid(MessageContentError.empty);
    }

    if (trimmed.length > maxLength) {
      return const MessageContentResult.invalid(MessageContentError.tooLong);
    }

    return MessageContentResult.valid(MessageContent._(trimmed));
  }

  /// A one-line preview for the conversation rail.
  ///
  /// Collapses newlines: a multi-line message would otherwise stretch a list
  /// row or be cut mid-character.
  String preview({int maxCharacters = 120}) {
    final collapsed = value.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (collapsed.length <= maxCharacters) return collapsed;

    return '${collapsed.substring(0, maxCharacters).trimRight()}…';
  }
}

enum MessageContentError { empty, tooLong }

sealed class MessageContentResult {
  const MessageContentResult();

  const factory MessageContentResult.valid(MessageContent content) =
      ValidMessageContent;

  const factory MessageContentResult.invalid(MessageContentError error) =
      InvalidMessageContent;
}

final class ValidMessageContent extends MessageContentResult {
  const ValidMessageContent(this.content);

  final MessageContent content;
}

final class InvalidMessageContent extends MessageContentResult {
  const InvalidMessageContent(this.error);

  final MessageContentError error;
}
