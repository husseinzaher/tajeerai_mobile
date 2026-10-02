import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/translations/app_strings.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/theme.dart';
import '../../../../design_system/design_system.dart';
import '../controllers/customer_note_form_controller.dart';

/// Writing an entry on a contact's record.
///
/// The screen keeps the draft and the way back; `CustomerNoteFormController`
/// owns the write and says why it did not happen. A failed send leaves the
/// words on screen, with a line saying why, rather than clearing the field and
/// asking somebody to remember what they typed.
class CustomerNoteFormScreen extends ConsumerStatefulWidget {
  const CustomerNoteFormScreen({required this.customerId, super.key});

  final String customerId;

  @override
  ConsumerState<CustomerNoteFormScreen> createState() =>
      _CustomerNoteFormScreenState();
}

class _CustomerNoteFormScreenState
    extends ConsumerState<CustomerNoteFormScreen> {
  final TextEditingController _body = TextEditingController();

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final bool saved = await ref
        .read(customerNoteFormControllerProvider.notifier)
        .save(customerId: widget.customerId, body: _body.text);

    if (!saved || !mounted) return;

    // Back to the record, which is where this was opened from -- and where
    // the entry just written now is. A deep link has nothing underneath it,
    // so that case goes to the contact rather than failing to pop.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.customerDetailPath(widget.customerId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final CustomerNoteFormState form = ref.watch(
      customerNoteFormControllerProvider,
    );

    return AppScaffold(
      toolbar: AppToolbar(title: strings.addNote, showBack: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(TajeerSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField(
              controller: _body,
              label: strings.noteBody,
              hintText: strings.noteHint,
              autofocus: true,
              minLines: 5,
              maxLines: 10,
              // The API caps an entry at five thousand characters. Enforced
              // here too, so nobody meets the limit as a failed Save after
              // writing past it.
              inputFormatters: <TextInputFormatter>[
                LengthLimitingTextInputFormatter(5000),
              ],
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
            if (form.error case final CustomerNoteFormError error) ...<Widget>[
              const SizedBox(height: TajeerSpacing.sm),
              AppInlineError(message: _describe(error, strings)),
            ],
            const SizedBox(height: TajeerSpacing.lg),
            AppButton(
              label: strings.save,
              loading: form.isSaving,
              expand: true,
              // An entry that says nothing still claims somebody was here, and
              // the API refuses it -- so the screen does not offer to send it.
              onPressed: _body.text.trim().isEmpty
                  ? null
                  : () => unawaited(_save()),
            ),
          ],
        ),
      ),
    );
  }

  static String _describe(CustomerNoteFormError error, AppStrings strings) =>
      switch (error) {
        CustomerNoteFormError.needsConnection => strings.noteNeedsConnection,
        CustomerNoteFormError.saveFailed => strings.noteSaveFailed,
      };
}
