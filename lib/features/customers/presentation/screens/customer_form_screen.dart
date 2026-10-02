import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/translations/app_strings.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/theme.dart';
import '../../../../design_system/design_system.dart';
import '../controllers/customer_form_controller.dart';

/// Adding a contact.
///
/// The screen owns the fields and the way out; `CustomerFormController` owns
/// the save -- the country-code check, the duplicate lookup and the write --
/// and reports where the contact is. A screen that did those itself would be
/// performing data access from the build tree, where it cannot be sequenced,
/// retried or tested on its own.
class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.initialPhone});

  /// Prefilled when this screen is opened from a call that was not a contact.
  final String? initialPhone;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  late final TextEditingController _name = TextEditingController();

  /// Opens on the country code rather than empty -- see
  /// [CustomerFormController.defaultCallingCode] for why.
  late final TextEditingController _phone = TextEditingController(
    text: widget.initialPhone ?? CustomerFormController.defaultCallingCode,
  );
  late final TextEditingController _email = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final CustomerFormOutcome? outcome = await ref
        .read(customerFormControllerProvider.notifier)
        .save(name: _name.text, phone: _phone.text, email: _email.text);

    if (!mounted) return;

    switch (outcome) {
      // Created, or found to exist already: either way the member is taken to
      // the contact rather than left on a form that has done its job.
      case CustomerSaved(:final String customerId):
      case CustomerAlreadyExisted(:final String customerId):
        context.pushReplacement(AppRoutes.customerDetailPath(customerId));
      case CustomerSaveRefused():
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final CustomerFormState form = ref.watch(customerFormControllerProvider);

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
              description: strings.phoneNeedsCountryCode,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: TajeerSpacing.md),
            AppTextField(
              controller: _email,
              label: strings.email,
              keyboardType: TextInputType.emailAddress,
            ),
            if (form.error case final CustomerFormError error) ...<Widget>[
              const SizedBox(height: TajeerSpacing.sm),
              AppInlineError(message: _describe(error, strings)),
            ],
            const SizedBox(height: TajeerSpacing.lg),
            AppButton(
              label: strings.save,
              loading: form.isSaving,
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

  /// The reason, in the reader's language.
  static String _describe(CustomerFormError error, AppStrings strings) =>
      switch (error) {
        CustomerFormError.phoneNeedsCountryCode =>
          strings.phoneNeedsCountryCode,
        CustomerFormError.needsConnection => strings.customerNeedsConnection,
        CustomerFormError.alreadyExists => strings.customerExists,
        CustomerFormError.saveFailed => strings.customerSaveFailed,
      };
}
