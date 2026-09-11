import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/theme.dart';
import '../../auth/auth_header.dart';
import '../../auth/auth_layout.dart';
import '../../auth/brand_logo.dart';
import '../../auth/social_button.dart';
import '../../display/labelled_separator.dart';
import '../../inputs/otp_field.dart';
import '../showcase_section.dart';

/// The parts every unauthenticated screen is built from.
///
/// Deliberately **not** a copy of the sign-in screen. That screen is rendered
/// from these same parts inside the app and captured as a golden; a second one
/// assembled here would be a second implementation, free to drift from the
/// real one without anything failing.
ShowcaseSection authenticationSection() => ShowcaseSection(
  title: 'Authentication',
  icon: LucideIcons.lockKeyhole,
  description:
      'The frame and the parts every unauthenticated screen is built from. The '
      'production sign-in screen is not repeated here: it is built from these '
      'same parts in the app.',
  examples: <ShowcaseExample>[
    ShowcaseExample(
      name: 'Brand logo',
      description:
          'Drawn from the brand\'s own exports, never redrawn. The vertical logo '
          'comes in four — an Arabic or Latin wordmark, yellow on a light canvas '
          'and white on a dark one — and the component picks between them, so no '
          'screen has to. The horizontal logo and the mark read on either canvas. '
          'None of them mirrors: a logo is a fixed graphic, not a sentence.',
      builder: (BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TajeerSpacing.lg,
        children: <Widget>[
          AppBrandLogo(),
          AppBrandLogo(variant: AppBrandLogoVariant.horizontal),
          AppBrandLogo(variant: AppBrandLogoVariant.mark),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Header',
      description: 'The title is announced as a heading.',
      builder: (BuildContext context) => const AppAuthHeader(
        title: 'مرحباً بعودتك',
        description: 'سجّل الدخول إلى حسابك لمتابعة أعمالك',
      ),
    ),
    ShowcaseExample(
      name: 'Social sign-in',
      description:
          'Not on the production screen: mobile has no OAuth flow yet, and a '
          'provider button that does nothing is worse than an absent one. '
          'Neutral glyphs here rather than imitating anybody\'s logo. The label '
          'is required, so a row of marks is never a row of identical buttons '
          'to a screen reader.',
      builder: (BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TajeerSpacing.md,
        children: <Widget>[
          const AppLabelledSeparator(label: 'أو تابع باستخدام'),
          Row(
            spacing: TajeerSpacing.xs,
            children: <Widget>[
              Expanded(
                child: AppSocialButton(
                  glyph: const Icon(LucideIcons.globe),
                  label: 'المتابعة عبر الموقع',
                  onPressed: () {},
                ),
              ),
              Expanded(
                child: AppSocialButton(
                  glyph: const Icon(LucideIcons.mail),
                  label: 'المتابعة عبر البريد',
                  onPressed: () {},
                ),
              ),
              Expanded(
                child: AppSocialButton(
                  glyph: const Icon(LucideIcons.store),
                  label: 'المتابعة عبر المتجر',
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'The frame, holding a one-time code',
      description:
          'AppAuthLayout centres when there is room and scrolls when there is '
          'not, stays out from under the keyboard, and caps its width. Framed '
          'at a fixed height here because it is a whole screen — in the app it '
          'is the entire body.',
      builder: (BuildContext context) => SizedBox(
        height: 560,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: TajeerRadii.lgAll,
            border: Border.fromBorderSide(
              BorderSide(color: context.colors.borderSubtle),
            ),
          ),
          child: const ClipRRect(
            borderRadius: TajeerRadii.lgAll,
            child: AppAuthLayout(
              logo: AppBrandLogo(variant: AppBrandLogoVariant.mark),
              header: AppAuthHeader(
                title: 'أدخل رمز التحقق',
                description: 'أرسلنا رمزاً من 6 أرقام إلى رقم هاتفك',
              ),
              // Not autofocused: in a gallery, a keyboard that opens the moment
              // you scroll past the example is the example misbehaving.
              child: AppOtpField(length: 6, autofocus: false),
            ),
          ),
        ),
      ),
    ),
  ],
);
