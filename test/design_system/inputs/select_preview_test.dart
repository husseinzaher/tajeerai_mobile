@Tags(<String>['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';
import 'package:tajeerai_mobile/design_system/inputs/app_select.dart';

import '../../support/golden_harness.dart';
import '../../support/widget_harness.dart';

/// The searchable select with its sheet open.
///
/// The closed control is visible in the Forms section's capture; this is the
/// state that carries the actual design decision — a sheet rather than a
/// popover — and it is the one nobody sees in a static screenshot of a form.
void main() {
  setUpAll(loadFonts);

  const List<AppSelectOption<String>> team = <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: '1',
      label: 'أحمد محمد',
      description: 'مالك المتجر',
    ),
    AppSelectOption<String>(
      value: '2',
      label: 'سارة أحمد',
      description: 'خدمة العملاء',
    ),
    AppSelectOption<String>(
      value: '3',
      label: 'خالد عبدالله',
      description: 'المبيعات',
    ),
    AppSelectOption<String>(
      value: '4',
      label: 'فاطمة الزهراء',
      description: 'التسويق',
    ),
    AppSelectOption<String>(
      value: '5',
      label: 'Reem Al-Saleh',
      description: 'Support',
    ),
    AppSelectOption<String>(
      value: '6',
      label: 'محمد علي',
      description: 'المبيعات',
    ),
  ];

  for (final GoldenVariant variant in goldenVariants) {
    testWidgets('searchable select sheet — ${variant.name}', (
      WidgetTester tester,
    ) async {
      final bool arabic = variant.direction == TextDirection.rtl;
      final String placeholder = arabic
          ? 'اختر عضو الفريق'
          : 'Choose a team member';

      useDevice(tester);
      await tester.pumpWidget(
        wrapWidget(
          Padding(
            padding: const EdgeInsets.all(TajeerSpacing.md),
            child: AppSelect<String>(
              label: arabic ? 'أسند إلى' : 'Assign to',
              placeholder: placeholder,
              searchable: true,
              value: null,
              options: team,
              onChanged: (_) {},
            ),
          ),
          brightness: variant.brightness,
          textDirection: variant.direction,
          locale: variant.locale,
          size: const Size(390, 844),
        ),
      );

      await tester.tap(find.text(placeholder));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/select_searchable_${variant.name}.png',
        ),
      );
    });
  }
}
