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
        PathClassifier.classify('lib/infrastructure/api/http_client.dart')
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
      };

      cases.forEach((path, expected) {
        expect(PathClassifier.classify(path).layer, expected, reason: path);
      });
    });

    test('a feature has exactly three layers; anything else is the root', () {
      // `data/` and `realtime/` used to be layers. Their contents are
      // infrastructure now, and a file left behind is a violation the
      // forbidden-directory rule reports -- not a layer of its own.
      for (final path in <String>[
        'lib/features/auth/data/repositories/auth_repository_impl.dart',
        'lib/features/auth/realtime/auth_socket_credentials.dart',
        'lib/features/auth/something_else/file.dart',
      ]) {
        final location = PathClassifier.classify(path);

        expect(location.layer, Layer.featureRoot, reason: path);
        expect(location.feature, 'auth');
      }
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

    test('normalises Windows separators', () {
      final location = PathClassifier.classify(
        r'lib\features\auth\domain\services\auth_service.dart',
      );

      expect(location.layer, Layer.domain);
      expect(location.feature, 'auth');
    });
  });

  group('infrastructure adapters', () {
    test('are their own layer, and carry the feature they serve', () {
      final location = PathClassifier.classify(
        'lib/infrastructure/adapters/conversations/repositories/'
        'message_repository_impl.dart',
      );

      expect(location.layer, Layer.adapter);
      // The feature-boundary rules read this, so an adapter is held to the
      // same boundary as the feature it implements.
      expect(location.feature, 'conversations');
      expect(location.isFeatureFile, isTrue);
    });

    test('the shared engines carry no feature', () {
      for (final path in <String>[
        'lib/infrastructure/socket/socket_manager.dart',
        'lib/infrastructure/storage/database/app_database.dart',
        'lib/infrastructure/device/platform_info.dart',
      ]) {
        final location = PathClassifier.classify(path);

        expect(location.layer, Layer.infrastructure, reason: path);
        expect(location.feature, isNull, reason: path);
      }
    });

    test('a file directly under adapters/ is an engine, not an adapter', () {
      // `adapters/<feature>/<file>` is the shallowest an adapter can be; a
      // stray file at `adapters/x.dart` has no feature to belong to.
      expect(
        PathClassifier.classify('lib/infrastructure/adapters/x.dart').layer,
        Layer.infrastructure,
      );
    });

    test('names the outward-facing parts of an application layer', () {
      for (final path in <String>[
        'lib/features/conversations/application/ports/conversation_remote_port.dart',
        'lib/features/auth/application/contracts/session_capability.dart',
        'lib/features/conversations/application/events/typing_changed.dart',
      ]) {
        expect(
          PathClassifier.isApplicationBoundary(path),
          isTrue,
          reason: path,
        );
      }

      for (final path in <String>[
        'lib/features/conversations/application/coordinators/outbox.dart',
        'lib/features/conversations/application/state/sync_state.dart',
      ]) {
        expect(
          PathClassifier.isApplicationBoundary(path),
          isFalse,
          reason: path,
        );
      }
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

    test('a generated DAO is an adapter like its source', () {
      final location = PathClassifier.classify(
        'lib/infrastructure/adapters/customers/local/customer_dao.g.dart',
      );

      expect(location.isGenerated, isTrue);
      expect(location.layer, Layer.adapter);
      expect(location.feature, 'customers');
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
