import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../../../app/localization/translations/app_strings.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/theme.dart';
import '../../../../design_system/design_system.dart';
import '../../../../failures/app_failure.dart';
import '../../domain/entities/customer.dart';
import '../../domain/value_objects/phone_digits.dart';

/// Adding a contact.
///
/// **Online only.** The record needs a server id before anything else can
/// point at it, and a contact created offline would be a second person the
/// moment somebody else added the same number.
///
/// Before it creates one it looks for the number among the contacts this
/// device already holds -- so the common case, a number that is already
/// somebody, opens them instead of quietly making a duplicate. The check is
/// local because that is where the caller card's own answer comes from: if
/// this device thinks the number is new, the card thought so too.
class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.initialPhone});

  /// Prefilled when this screen is opened from a call that was not a contact.
  final String? initialPhone;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  late final TextEditingController _name = TextEditingController();
  late final TextEditingController _phone = TextEditingController(
    text: widget.initialPhone ?? '',
  );
  late final TextEditingController _email = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _name.text.trim();

    if (name.isEmpty || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final AppStrings strings = ref.read(appStringsProvider);
    final String phone = _phone.text.trim();

    try {
      // The duplicate check, before the write rather than after it: a contact
      // created and then found to exist is two rows somebody has to merge.
      if (phone.isNotEmpty && PhoneDigits.bare(phone).isNotEmpty) {
        final Customer? existing = await ref
            .read(customerRepositoryProvider)
            .findByPhone(phone);

        if (existing != null) {
          if (!mounted) return;

          context.pushReplacement(AppRoutes.customerDetailPath(existing.id));

          return;
        }
      }

      final Customer created = await ref
          .read(customerRepositoryProvider)
          .create(
            name: name,
            phone: phone.isEmpty ? null : phone,
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          );

      if (!mounted) return;

      context.pushReplacement(AppRoutes.customerDetailPath(created.id));
    } on AppFailure catch (failure) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = switch (failure) {
          TransportFailure(isOffline: true) => strings.customerNeedsConnection,
          ConflictFailure() => strings.customerExists,
          _ => strings.customerSaveFailed,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(appStringsProvider);

    return AppScaffold(
      toolbar: AppToolbar(title: strings.newCustomer, showBack: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(TajeerSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField(
              controller: _name,
              label: strings.customerName,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: TajeerSpacing.md),
            AppTextField(
              controller: _phone,
              label: strings.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: TajeerSpacing.md),
            AppTextField(
              controller: _email,
              label: strings.email,
              keyboardType: TextInputType.emailAddress,
            ),
            if (_error case final String message) ...<Widget>[
              const SizedBox(height: TajeerSpacing.sm),
              AppInlineError(message: message),
            ],
            const SizedBox(height: TajeerSpacing.lg),
            AppButton(
              label: strings.save,
              loading: _saving,
              expand: true,
              onPressed: _name.text.trim().isEmpty
                  ? null
                  : () => unawaited(_save()),
            ),
          ],
        ),
      ),
    );
  }
}
