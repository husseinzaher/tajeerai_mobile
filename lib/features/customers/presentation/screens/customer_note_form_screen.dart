import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../../../app/localization/translations/app_strings.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/theme.dart';
import '../../../../design_system/design_system.dart';
import '../../../../failures/app_failure.dart';

/// Writing an entry on a contact's record.
///
/// **Online only, and it says so.** The server stamps the entry with who wrote
/// it and when, and there is no local identity to stamp it with in the
/// meantime -- so this does not queue through the outbox the way a message
/// does. What it does instead is keep the draft: a failed send leaves the
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
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String body = _body.text.trim();

    if (body.isEmpty || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final AppStrings strings = ref.read(appStringsProvider);

    try {
      await ref
          .read(customerRepositoryProvider)
          .addNote(widget.customerId, body);

      if (!mounted) return;

      // Back to the record, which is where this was opened from -- and where
      // the entry just written now is. A deep link has nothing underneath it,
      // so that case goes to the contact rather than failing to pop.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.customerDetailPath(widget.customerId));
      }
    } on AppFailure catch (failure) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = switch (failure) {
          TransportFailure(isOffline: true) => strings.noteNeedsConnection,
          _ => strings.noteSaveFailed,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(appStringsProvider);

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
            if (_error case final String message) ...<Widget>[
              const SizedBox(height: TajeerSpacing.sm),
              AppInlineError(message: message),
            ],
            const SizedBox(height: TajeerSpacing.lg),
            AppButton(
              label: strings.save,
              loading: _saving,
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
}
