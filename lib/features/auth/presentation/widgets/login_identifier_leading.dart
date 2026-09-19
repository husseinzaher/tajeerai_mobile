import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/theme.dart';
import '../../domain/value_objects/login_phone_reader.dart';

/// The icon the sign-in identifier field shows: mail, phone, or a country flag.
class LoginIdentifierLeading extends StatelessWidget {
  const LoginIdentifierLeading({required this.value, super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    if (!LoginPhoneReader.isPhoneShaped(value)) {
      return const Icon(LucideIcons.mail);
    }

    final DialledNumber? phone = LoginPhoneReader.readPhoneNumber(value);
    final String? country = phone?.country;

    if (country != null && country.length == 2) {
      return Text(
        _flagEmoji(country),
        style: context.type.titleLg.copyWith(height: 1),
      );
    }

    return const Icon(LucideIcons.phone);
  }

  static String _flagEmoji(String countryCode) {
    final String upper = countryCode.toUpperCase();

    return String.fromCharCodes(
      upper.codeUnits.map((int unit) => 0x1F1E6 + unit - 0x41),
    );
  }
}
