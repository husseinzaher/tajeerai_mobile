@Tags(<String>['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/bootstrap/dependencies.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';
import 'package:tajeerai_mobile/features/auth/application/coordinators/session_coordinator.dart';
import 'package:tajeerai_mobile/features/auth/domain/services/auth_service.dart';
import 'package:tajeerai_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:tajeerai_mobile/infrastructure/logging/logger.dart';

import '../../../support/golden_harness.dart';
import '../../../support/widget_harness.dart';
import '../domain/fakes/fake_auth_repository.dart';

/// The production sign-in screen, under every preset and both appearances.
///
/// Deliberately the real screen over a fake repository rather than a mock-up:
/// the point of a preset is that the screen nobody rewrote comes out looking
/// like the new product, and a preview built specially would prove nothing.
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

  for (final TajeerPreset preset in TajeerPreset.values) {
    for (final Brightness brightness in Brightness.values) {
      testWidgets('login ${preset.name} ${brightness.name}', (
        WidgetTester tester,
      ) async {
        useDevice(tester);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionCoordinatorProvider.overrideWithValue(coordinator),
            ],
            child: wrapWidget(
              const LoginScreen(),
              preset: preset,
              brightness: brightness,
              textDirection: TextDirection.rtl,
              size: const Size(390, 844),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../../goldens/login_${preset.name}_${brightness.name}.png',
          ),
        );
      });
    }
  }
}
