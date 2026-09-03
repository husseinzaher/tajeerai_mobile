import 'package:flutter_test/flutter_test.dart';

import '../../tool/architecture/path_classifier.dart';

void main() {
  group('layer classification', () {
    test('recognises the root layers', () {
      expect(
        PathClassifier.classify('lib/app/router/app_router.dart').layer,
        Layer.app,
      );
      expect(
        PathClassifier.classify('lib/design_system/buttons/app_button.dart')
            .layer,
        Layer.designSystem,
      );
      expect(
        PathClassifier.classify('lib/infrastructure/network/http_client.dart')
            .layer,
        Layer.infrastructure,
      );
      expect(
        PathClassifier.classify('lib/failures/app_failure.dart').layer,
        Layer.failures,
      );
    });

    test('recognises each feature layer', () {
      const cases = <String, Layer>{
        'lib/features/auth/presentation/screens/login_screen.dart':
            Layer.presentation,
        'lib/features/auth/application/state/auth_state.dart':
            Layer.application,
        'lib/features/auth/domain/services/auth_service.dart': Layer.domain,
        'lib/features/auth/data/repositories/auth_repository_impl.dart':
            Layer.data,
        'lib/features/auth/realtime/auth_socket_credentials.dart':
            Layer.featureRealtime,
      };

      cases.forEach((path, expected) {
        expect(PathClassifier.classify(path).layer, expected, reason: path);
      });
    });

    test('names the owning feature', () {
      expect(
        PathClassifier.classify(
          'lib/features/conversations/domain/entities/message.dart',
        ).feature,
        'conversations',
      );
    });

    test('treats main.dart and tooling as other', () {
      expect(PathClassifier.classify('lib/main.dart').layer, Layer.other);
      expect(
        PathClassifier.classify('tool/check_architecture.dart').layer,
        Layer.other,
      );
      expect(
        PathClassifier.classify('test/features/auth/x_test.dart').layer,
        Layer.other,
      );
    });

    test('classifies an unrecognised feature subdirectory as the root', () {
      final location = PathClassifier.classify(
        'lib/features/auth/something_else/file.dart',
      );

      expect(location.layer, Layer.featureRoot);
      expect(location.feature, 'auth');
    });

    test('normalises Windows separators', () {
      final location = PathClassifier.classify(
        r'lib\features\auth\domain\services\auth_service.dart',
      );

      expect(location.layer, Layer.domain);
      expect(location.feature, 'auth');
    });
  });

  group('generated files', () {
    test('are flagged but still classified into their layer', () {
      final location = PathClassifier.classify(
        'lib/features/conversations/presentation/controllers/x.g.dart',
      );

      // Generated code is subject to the boundaries like anything else -- it
      // must not become a bypass.
      expect(location.isGenerated, isTrue);
      expect(location.layer, Layer.presentation);
    });

    test('recognise freezed output', () {
      expect(
        PathClassifier.classify('lib/features/auth/domain/x.freezed.dart')
            .isGenerated,
        isTrue,
      );
    });

    test('a hand-written file is not flagged', () {
      expect(PathClassifier.classify('lib/main.dart').isGenerated, isFalse);
    });
  });

  group('UI helpers', () {
    test('identify screens and widgets', () {
      expect(
        PathClassifier.isWidgetOrScreen(
          'lib/features/auth/presentation/screens/login_screen.dart',
        ),
        isTrue,
      );
      expect(
        PathClassifier.isWidgetOrScreen(
          'lib/features/auth/presentation/widgets/login_form.dart',
        ),
        isTrue,
      );

      // A controller may hold a service reference a widget may not.
      expect(
        PathClassifier.isWidgetOrScreen(
          'lib/features/auth/presentation/controllers/login_controller.dart',
        ),
        isFalse,
      );
    });

    test('identify controllers', () {
      expect(
        PathClassifier.isController(
          'lib/features/auth/presentation/controllers/login_controller.dart',
        ),
        isTrue,
      );
    });
  });
}
