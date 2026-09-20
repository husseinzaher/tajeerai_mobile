/// Every Caller Card preference the member can change.
final class CallerIdSettings {
  const CallerIdSettings({
    this.enabled = false,
    this.showIncoming = true,
    this.showOutgoing = true,
    this.showOnlyUnknown = false,
    this.showContacts = true,
    this.autoDismissSeconds = 15,
    this.cardEnabled = true,
    this.cardPosition = CallerCardPosition.top,
    this.cardSize = CallerCardLayout.compact,
    this.showAvatar = true,
    this.showCallerName = true,
    this.showPhoneNumber = true,
    this.showTags = true,
    this.showSpamStatus = true,
    this.showBusinessInfo = true,
    this.animationEnabled = true,
    this.showOverOtherApps = true,
    this.dismissOnTap = true,
    this.localLookupEnabled = true,
    this.serverLookupEnabled = true,
    this.useCachedData = true,
  });

  final bool enabled;
  final bool showIncoming;
  final bool showOutgoing;
  final bool showOnlyUnknown;
  final bool showContacts;
  final int autoDismissSeconds;
  final bool cardEnabled;
  final CallerCardPosition cardPosition;
  final CallerCardLayout cardSize;
  final bool showAvatar;
  final bool showCallerName;
  final bool showPhoneNumber;
  final bool showTags;
  final bool showSpamStatus;
  final bool showBusinessInfo;
  final bool animationEnabled;
  final bool showOverOtherApps;
  final bool dismissOnTap;
  final bool localLookupEnabled;
  final bool serverLookupEnabled;
  final bool useCachedData;

  bool shouldShowFor({required bool isIncoming, required bool isKnownContact}) {
    if (!enabled || !cardEnabled) return false;

    if (isIncoming && !showIncoming) return false;
    if (!isIncoming && !showOutgoing) return false;
    if (showOnlyUnknown && isKnownContact) return false;
    if (!showContacts && isKnownContact) return false;

    return true;
  }

  CallerIdSettings copyWith({
    bool? enabled,
    bool? showIncoming,
    bool? showOutgoing,
    bool? showOnlyUnknown,
    bool? showContacts,
    int? autoDismissSeconds,
    bool? cardEnabled,
    CallerCardPosition? cardPosition,
    CallerCardLayout? cardSize,
    bool? showAvatar,
    bool? showCallerName,
    bool? showPhoneNumber,
    bool? showTags,
    bool? showSpamStatus,
    bool? showBusinessInfo,
    bool? animationEnabled,
    bool? showOverOtherApps,
    bool? dismissOnTap,
    bool? localLookupEnabled,
    bool? serverLookupEnabled,
    bool? useCachedData,
  }) {
    return CallerIdSettings(
      enabled: enabled ?? this.enabled,
      showIncoming: showIncoming ?? this.showIncoming,
      showOutgoing: showOutgoing ?? this.showOutgoing,
      showOnlyUnknown: showOnlyUnknown ?? this.showOnlyUnknown,
      showContacts: showContacts ?? this.showContacts,
      autoDismissSeconds: autoDismissSeconds ?? this.autoDismissSeconds,
      cardEnabled: cardEnabled ?? this.cardEnabled,
      cardPosition: cardPosition ?? this.cardPosition,
      cardSize: cardSize ?? this.cardSize,
      showAvatar: showAvatar ?? this.showAvatar,
      showCallerName: showCallerName ?? this.showCallerName,
      showPhoneNumber: showPhoneNumber ?? this.showPhoneNumber,
      showTags: showTags ?? this.showTags,
      showSpamStatus: showSpamStatus ?? this.showSpamStatus,
      showBusinessInfo: showBusinessInfo ?? this.showBusinessInfo,
      animationEnabled: animationEnabled ?? this.animationEnabled,
      showOverOtherApps: showOverOtherApps ?? this.showOverOtherApps,
      dismissOnTap: dismissOnTap ?? this.dismissOnTap,
      localLookupEnabled: localLookupEnabled ?? this.localLookupEnabled,
      serverLookupEnabled: serverLookupEnabled ?? this.serverLookupEnabled,
      useCachedData: useCachedData ?? this.useCachedData,
    );
  }

  Map<String, Object> toNativeMap() => <String, Object>{
    'enabled': enabled,
    'showIncoming': showIncoming,
    'showOutgoing': showOutgoing,
    'showOnlyUnknown': showOnlyUnknown,
    'showContacts': showContacts,
    'autoDismissSeconds': autoDismissSeconds,
    'cardEnabled': cardEnabled,
    'cardPosition': cardPosition.name,
    'cardSize': cardSize.name,
    'showAvatar': showAvatar,
    'showCallerName': showCallerName,
    'showPhoneNumber': showPhoneNumber,
    'showTags': showTags,
    'showSpamStatus': showSpamStatus,
    'showBusinessInfo': showBusinessInfo,
    'animationEnabled': animationEnabled,
    'showOverOtherApps': showOverOtherApps,
    'dismissOnTap': dismissOnTap,
    'localLookupEnabled': localLookupEnabled,
    'serverLookupEnabled': serverLookupEnabled,
    'useCachedData': useCachedData,
  };

  static CallerIdSettings fromJson(Map<String, Object?> json) {
    return CallerIdSettings(
      enabled: json['enabled'] == true,
      showIncoming: json['showIncoming'] != false,
      showOutgoing: json['showOutgoing'] != false,
      showOnlyUnknown: json['showOnlyUnknown'] == true,
      showContacts: json['showContacts'] != false,
      autoDismissSeconds: _readInt(json['autoDismissSeconds'], fallback: 15),
      cardEnabled: json['cardEnabled'] != false,
      cardPosition: CallerCardPosition.fromName(
        json['cardPosition']?.toString(),
      ),
      cardSize: CallerCardLayout.fromName(json['cardSize']?.toString()),
      showAvatar: json['showAvatar'] != false,
      showCallerName: json['showCallerName'] != false,
      showPhoneNumber: json['showPhoneNumber'] != false,
      showTags: json['showTags'] != false,
      showSpamStatus: json['showSpamStatus'] != false,
      showBusinessInfo: json['showBusinessInfo'] != false,
      animationEnabled: json['animationEnabled'] != false,
      showOverOtherApps: json['showOverOtherApps'] != false,
      dismissOnTap: json['dismissOnTap'] != false,
      localLookupEnabled: json['localLookupEnabled'] != false,
      serverLookupEnabled: json['serverLookupEnabled'] != false,
      useCachedData: json['useCachedData'] != false,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'enabled': enabled,
    'showIncoming': showIncoming,
    'showOutgoing': showOutgoing,
    'showOnlyUnknown': showOnlyUnknown,
    'showContacts': showContacts,
    'autoDismissSeconds': autoDismissSeconds,
    'cardEnabled': cardEnabled,
    'cardPosition': cardPosition.name,
    'cardSize': cardSize.name,
    'showAvatar': showAvatar,
    'showCallerName': showCallerName,
    'showPhoneNumber': showPhoneNumber,
    'showTags': showTags,
    'showSpamStatus': showSpamStatus,
    'showBusinessInfo': showBusinessInfo,
    'animationEnabled': animationEnabled,
    'showOverOtherApps': showOverOtherApps,
    'dismissOnTap': dismissOnTap,
    'localLookupEnabled': localLookupEnabled,
    'serverLookupEnabled': serverLookupEnabled,
    'useCachedData': useCachedData,
  };

  static int _readInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return fallback;
  }
}

enum CallerCardPosition {
  top,
  center,
  bottom;

  static CallerCardPosition fromName(String? raw) => switch (raw) {
    'center' => CallerCardPosition.center,
    'bottom' => CallerCardPosition.bottom,
    _ => CallerCardPosition.top,
  };
}

enum CallerCardLayout {
  compact,
  full;

  static CallerCardLayout fromName(String? raw) =>
      raw == 'full' ? CallerCardLayout.full : CallerCardLayout.compact;
}
