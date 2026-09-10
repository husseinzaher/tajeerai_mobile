@Tags(<String>['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';
import 'package:tajeerai_mobile/design_system/atoms/avatar.dart';
import 'package:tajeerai_mobile/design_system/atoms/badge.dart';
import 'package:tajeerai_mobile/design_system/buttons/app_button.dart';
import 'package:tajeerai_mobile/design_system/cards/app_card.dart';
import 'package:tajeerai_mobile/design_system/feedback/empty_state.dart';
import 'package:tajeerai_mobile/design_system/inputs/app_text_field.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../support/golden_harness.dart';
import '../support/widget_harness.dart';

/// One sheet of the shared components, rendered under every preset.
///
/// This is the visual half of the contract the contrast test checks
/// numerically: the *same* widgets, given nothing but a different `ThemeData`,
/// have to come out looking like two deliberate products rather than one
/// product and one recolouring accident.
class _Sheet extends StatelessWidget {
  const _Sheet(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    return ColoredBox(
      color: colors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TajeerSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: TajeerSpacing.sm,
          children: <Widget>[
            Text('Tajeer AI', style: context.type.headlineMd),
            Text(
              title,
              style: context.type.labelSm.copyWith(color: colors.textMuted),
            ),
            Text('تواصل. إدارة. نمو.', style: context.type.bodyMd),
            AppButton(
              label: 'تسجيل الدخول',
              size: AppButtonSize.large,
              expand: true,
              trailing: const Icon(LucideIcons.arrowLeft),
              onPressed: () {},
            ),
            Row(
              spacing: TajeerSpacing.xs,
              children: <Widget>[
                Expanded(
                  child: AppButton(
                    label: 'ثانوي',
                    variant: AppButtonVariant.secondary,
                    onPressed: () {},
                  ),
                ),
                Expanded(
                  child: AppButton(
                    label: 'محدد',
                    variant: AppButtonVariant.outline,
                    onPressed: () {},
                  ),
                ),
                AppButton.icon(
                  icon: const Icon(LucideIcons.ellipsis),
                  semanticLabel: 'المزيد',
                  onPressed: () {},
                ),
              ],
            ),
            AppTextField(
              label: 'البريد الإلكتروني',
              hintText: 'name@yourstore.com',
              leading: const Icon(LucideIcons.mail),
            ),
            AppTextField(
              label: 'كلمة المرور',
              hintText: '••••••••',
              errorText: 'كلمة المرور غير صحيحة',
              leading: const Icon(LucideIcons.lock),
            ),
            AppCard(
              child: Row(
                spacing: TajeerSpacing.sm,
                children: <Widget>[
                  const AppAvatar(name: 'سارة أحمد'),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('سارة أحمد', style: context.type.titleSm),
                        Text(
                          'مرحباً، هل المنتج ما زال متوفر؟',
                          style: context.type.bodySm.copyWith(
                            color: colors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const AppBadge(label: '3'),
                ],
              ),
            ),
            Wrap(
              spacing: TajeerSpacing.xs,
              runSpacing: TajeerSpacing.xs,
              children: const <Widget>[
                AppBadge(label: 'مثبّتة'),
                AppBadge(label: 'مهمة', variant: AppBadgeVariant.secondary),
                AppBadge(label: 'تم', variant: AppBadgeVariant.success),
                AppBadge(label: 'فشل', variant: AppBadgeVariant.destructive),
                AppBadge(label: 'الكل', variant: AppBadgeVariant.outline),
              ],
            ),
            const EmptyState(
              title: 'لا توجد محادثات بعد',
              description: 'ستظهر هنا المحادثات الواردة من قنوات التواصل.',
              icon: LucideIcons.messageCircle,
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  setUpAll(loadFonts);

  for (final TajeerPreset preset in TajeerPreset.values) {
    for (final Brightness brightness in Brightness.values) {
      testWidgets('${preset.name} ${brightness.name}', (
        WidgetTester tester,
      ) async {
        useDevice(tester);
        await tester.pumpWidget(
          wrapWidget(
            _Sheet(preset.name),
            preset: preset,
            brightness: brightness,
            textDirection: TextDirection.rtl,
            size: const Size(390, 844),
          ),
        );
        // Never pumpAndSettle: Spinner and Skeleton repeat() forever.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // A golden blesses whatever it is given, overflow stripes included.
        // This is the assertion that stops one being committed.
        expect(tester.takeException(), isNull);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../goldens/${preset.name}_${brightness.name}.png'),
        );
      });
    }
  }
}
