@Tags(<String>['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:TajeerAi/app/bootstrap/dependencies.dart';
import 'package:TajeerAi/features/auth/application/coordinators/session_coordinator.dart';
import 'package:TajeerAi/features/auth/domain/services/auth_service.dart';
import 'package:TajeerAi/features/auth/presentation/screens/login_screen.dart';
import 'package:TajeerAi/infrastructure/device/platform_info.dart';
import 'package:TajeerAi/infrastructure/logging/logger.dart';
import 'package:TajeerAi/infrastructure/storage/preferences_storage.dart';

import '../../../support/golden_harness.dart';
import '../../../support/widget_harness.dart';
import '../domain/fakes/fake_auth_repository.dart';

/// The production sign-in screen, in both golden variants.
///
/// Deliberately the real screen over a fake repository rather than a mock-up:
/// the screen nobody rewrote has to come out looking like the product, and a
/// preview built specially would prove nothing. The second preset's palette is
/// pinned by the Foundations capture rather than repeated here.
void main() {
  setUpAll(loadFonts);

  late SessionCoordinator coordinator;

  setUp(() {
    coordinator = SessionCoordinator(
      authService: AuthService(FakeAuthRepository()),
      logger: Logger('test', verbose: false),
    );
  });

  tearDown(() => coordinator.dispose());

  for (final GoldenVariant variant in goldenVariants) {
    testWidgets('login ${variant.name}', (WidgetTester tester) async {
      // Arabic is a fresh install, with nothing stored. English is a member
      // who chose it, so the screen's own copy reads the way the layout runs.
      SharedPreferences.setMockInitialValues(<String, Object>{
        if (variant.locale.languageCode != 'ar')
          PreferencesStorage.localeKey: variant.locale.languageCode,
      });
      final PreferencesStorage preferences = await PreferencesStorage.open();

      useDevice(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionCoordinatorProvider.overrideWithValue(coordinator),
            preferencesStorageProvider.overrideWithValue(preferences),
            platformInfoProvider.overrideWithValue(
              const PlatformInfo(
                appVersion: '1.0.0',
                buildNumber: '1',
                operatingSystem: 'android',
              ),
            ),
          ],
          child: wrapWidget(
            const LoginScreen(),
            brightness: variant.brightness,
            textDirection: variant.direction,
            locale: variant.locale,
            size: const Size(390, 844),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await precacheImages(tester);

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../../goldens/login_${variant.name}.png'),
      );
    });
  }
}
