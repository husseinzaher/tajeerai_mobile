/// Who a phone number resolves to for the Caller Card.
final class CallerIdentity {
  const CallerIdentity({
    required this.phoneNumber,
    this.displayName,
    this.businessName,
    this.avatarUrl,
    this.spamStatus = CallerSpamStatus.unknown,
    this.tags = const <String>[],
    this.source = CallerIdentitySource.unknown,
    this.customerId,
  });

  final String phoneNumber;
  final String? displayName;
  final String? businessName;
  final String? avatarUrl;
  final CallerSpamStatus spamStatus;
  final List<String> tags;
  final CallerIdentitySource source;

  /// When the match came from the workspace directory.
  final String? customerId;

  bool get isKnown =>
      displayName != null && displayName!.trim().isNotEmpty;

  String get primaryLabel {
    final String? name = displayName?.trim();

    if (name != null && name.isNotEmpty) return name;

    return phoneNumber;
  }

  String? get secondaryLabel {
    final String? business = businessName?.trim();

    if (business != null && business.isNotEmpty) return business;

    if (isKnown) return phoneNumber;

    return null;
  }

  CallerIdentity copyWith({
    String? displayName,
    String? businessName,
    String? avatarUrl,
    CallerSpamStatus? spamStatus,
    List<String>? tags,
    CallerIdentitySource? source,
    String? customerId,
  }) {
    return CallerIdentity(
      phoneNumber: phoneNumber,
      displayName: displayName ?? this.displayName,
      businessName: businessName ?? this.businessName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      spamStatus: spamStatus ?? this.spamStatus,
      tags: tags ?? this.tags,
      source: source ?? this.source,
      customerId: customerId ?? this.customerId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CallerIdentity &&
      other.phoneNumber == phoneNumber &&
      other.displayName == displayName &&
      other.businessName == businessName &&
      other.avatarUrl == avatarUrl &&
      other.spamStatus == spamStatus &&
      other.source == source &&
      other.customerId == customerId &&
      _sameTags(other.tags, tags);

  @override
  int get hashCode => Object.hash(
    phoneNumber,
    displayName,
    businessName,
    avatarUrl,
    spamStatus,
    source,
    customerId,
    tags.length,
  );

  static bool _sameTags(List<String> a, List<String> b) {
    if (a.length != b.length) return false;

    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }
}

enum CallerSpamStatus { unknown, safe, suspected, spam }

enum CallerIdentitySource {
  unknown,
  localCustomer,
  localCache,
  server,
  deviceContact,
}
