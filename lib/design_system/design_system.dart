/// The design system's public surface.
///
/// A feature imports this and nothing else from `design_system/`. That is a
/// rule with a guard behind it (RULE 31), and it buys two things: a screen
/// carrying a dozen `../../../../design_system/...` lines is unreadable, and
/// this file is the reviewable statement of what the system offers — the same
/// job the web package's barrel does.
///
/// **Design-system files do not import this.** They import each other by
/// relative path. A barrel that imports itself is a cycle waiting to happen,
/// and it would make every component's analysis depend on every other's.
///
/// **Tests import the leaf they are testing**, not this. Coverage is measured
/// per *loaded* library, so a direct barrel import pulls all of them into a
/// test that touches one — including pure unit tests that render nothing.
///
/// It does not follow that the record set stays small: features import this
/// file, and a feature's widget test therefore loads the whole system anyway.
/// The measured effect of introducing the barrel was overall coverage moving
/// 87.2% -> 82.9%, because ~150 component lines that previously had no lcov
/// record at all now have one. That is the honest state of it: **every
/// component added here is counted from the day it lands, whether or not
/// anybody tested it.** Which is the right pressure, and worth knowing before
/// adding sixty files.
library;

export 'auth/auth_header.dart';
export 'auth/auth_layout.dart';
export 'auth/brand_logo.dart';
export 'auth/social_button.dart';
export 'buttons/app_button.dart';
export 'cards/app_card.dart';
export 'display/avatar.dart';
export 'display/avatar_group.dart';
export 'display/badge.dart';
export 'display/chip.dart';
export 'display/labelled_separator.dart';
export 'display/list_item.dart';
export 'display/list_section.dart';
export 'display/relative_time.dart';
export 'display/section_header.dart';
export 'display/segmented_control.dart';
export 'display/separator.dart';
export 'display/status_dot.dart';
export 'display/tabs.dart';
export 'feedback/async_view.dart';
export 'feedback/empty_state.dart';
export 'feedback/error_state.dart';
export 'feedback/inline_error.dart';
export 'feedback/progress_bar.dart';
export 'feedback/status_banner.dart';
export 'feedback/tooltip.dart';
export 'inputs/app_checkbox.dart';
export 'inputs/app_radio.dart';
export 'inputs/app_select.dart';
export 'inputs/app_switch.dart';
export 'inputs/app_text_field.dart';
export 'inputs/field_scaffold.dart';
export 'inputs/field_surface.dart';
export 'inputs/otp_field.dart';
export 'inputs/password_field.dart';
export 'inputs/search_field.dart';
export 'layouts/app_scaffold.dart';
export 'layouts/responsive.dart';
export 'localization/ds_localization.dart';
export 'localization/ds_messages.dart';
export 'loaders/app_splash.dart';
export 'loaders/skeleton.dart';
export 'loaders/spinner.dart';
export 'overlays/action_sheet.dart';
export 'overlays/app_bottom_sheet.dart';
export 'overlays/app_dialog.dart';
export 'overlays/app_snackbar.dart';
export 'primitives/pressable.dart';
