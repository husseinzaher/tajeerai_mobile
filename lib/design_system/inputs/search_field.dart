import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_text_field.dart';

import '../../app/theme/theme.dart';

/// A text field pre-composed for search.
///
/// Composition over a new primitive: this is [AppTextField] with the magnifier
/// and the clear affordance the web's search inputs carry, not a second input
/// implementation. The web theme hides the native `::-webkit-search-cancel`
/// and draws its own clear control, which is what the trailing slot does here.
class SearchField extends StatefulWidget {
  const SearchField({
    required this.controller,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    super.key,
  });

  final TextEditingController controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool enabled;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// The clear button appears and disappears with the text, so the field has
  /// to rebuild on edits the parent may not be listening for.
  void _onControllerChanged() => setState(() {});

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return AppTextField(
      controller: widget.controller,
      hintText: widget.hintText,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.search,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      leading: const Icon(LucideIcons.search),
      trailing: hasText
          ? GestureDetector(
              onTap: _clear,
              behavior: HitTestBehavior.opaque,
              child: Semantics(
                button: true,
                label: MaterialLocalizations.of(context).deleteButtonTooltip,
                child: Icon(LucideIcons.x, color: context.colors.textMuted),
              ),
            )
          : null,
    );
  }
}
