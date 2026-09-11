import 'package:flutter_test/flutter_test.dart';

import '../../tool/architecture/architecture_rule.dart';
import '../../tool/architecture/import_analyzer.dart';
import '../../tool/architecture/path_classifier.dart';
import '../../tool/architecture/rules/design_system_boundary_rule.dart';
import '../../tool/architecture/rules/design_system_usage_rule.dart';
import '../../tool/architecture/rules/feature_boundary_rule.dart';
import '../../tool/architecture/rules/forbidden_directory_rule.dart';
import '../../tool/architecture/rules/http_transport_rule.dart';
import '../../tool/architecture/rules/infrastructure_rule.dart';
import '../../tool/architecture/rules/layer_dependency_rule.dart';
import '../../tool/architecture/rules/presentation_access_rule.dart';

/// Builds a context for a hypothetical file with hypothetical imports.
///
/// The rules are pure functions of (file, imports, source), which is what lets
/// every one of them be tested without writing a Dart file to disk.
ArchitectureContext contextFor(
  String path,
  List<String> importPaths, {
  List<String> packages = const <String>[],
  String source = '',
}) {
  final imports = <ResolvedImport>[
    for (var index = 0; index < importPaths.length; index++)
      ResolvedImport(
        raw: importPaths[index],
        line: index + 1,
        projectPath: importPaths[index],
      ),
    for (var index = 0; index < packages.length; index++)
      ResolvedImport(
        raw: 'package:${packages[index]}/x.dart',
        line: importPaths.length + index + 1,
        packageName: packages[index],
      ),
  ];

  return ArchitectureContext(
    file: PathClassifier.classify(path),
    imports: imports,
    allFiles: const <FileLocation>[],
    source: source,
  );
}

void main() {
  group('RULE 1 -- presentation must not import data', () {
    test('flags a screen importing a repository implementation', () {
      final violations = const LayerDependencyRule().check(
        contextFor(
          'lib/features/auth/presentation/screens/login_screen.dart',
          <String>[
            'lib/features/auth/data/repositories/auth_repository_impl.dart',
          ],
        ),
      );

      expect(violations, hasLength(1));
      expect(violations.single.rule, contains('RULE 1'));
    });

    test('allows a controller importing a domain service', () {
      final violations = const LayerDependencyRule().check(
        contextFor(
          'lib/features/auth/presentation/controllers/login_controller.dart',
          <String>['lib/features/auth/domain/services/auth_service.dart'],
        ),
      );

      expect(violations, isEmpty);
    });
  });

  group('RULE 2 -- presentation must not import infrastructure', () {
    test('flags a screen importing the socket manager', () {
      final violations = const LayerDependencyRule().check(
        contextFor(
          'lib/features/conversations/presentation/screens/thread.dart',
          <String>['lib/infrastructure/realtime/socket_manager.dart'],
        ),
      );

      expect(violations, hasLength(1));
      expect(violations.single.rule, contains('RULE 2'));
    });
  });

  group('RULES 6-9 -- the domain stays framework-free', () {
    test('flags Flutter in a domain service', () {
      final violations = const LayerDependencyRule().check(
        contextFor(
          'lib/features/auth/domain/services/auth_service.dart',
          const <String>[],
          packages: <String>['flutter'],
        ),
      );

      expect(violations, hasLength(1));
      expect(violations.single.reason, contains('Flutter'));
    });

    test('flags Riverpod, Dio, drift and the socket client alike', () {
      for (final package in <String>[
        'flutter_riverpod',
        'dio',
        'drift',
        'socket_io_client',
        'go_router',
      ]) {
        final violations = const LayerDependencyRule().check(
          contextFor(
            'lib/features/auth/domain/services/auth_service.dart',
            const <String>[],
            packages: <String>[package],
          ),
        );

        expect(violations, hasLength(1), reason: package);
      }
    });

    test('allows the failure taxonomy, which is dependency-free', () {
      final violations = const LayerDependencyRule().check(
        contextFor(
          'lib/features/auth/domain/services/auth_service.dart',
          <String>['lib/failures/app_failure.dart'],
        ),
      );

      expect(violations, isEmpty);
    });

    test('flags the domain importing infrastructure', () {
      final violations = const LayerDependencyRule().check(
        contextFor(
          'lib/features/auth/domain/services/auth_service.dart',
          <String>['lib/infrastructure/network/http_client.dart'],
        ),
      );

      expect(violations, hasLength(1));
    });

    test('flags the domain importing its own feature data layer', () {
      final violations = const LayerDependencyRule().check(
        contextFor(
          'lib/features/auth/domain/services/auth_service.dart',
          <String>['lib/features/auth/data/local/auth_local_data_source.dart'],
        ),
      );

      expect(violations, hasLength(1));
    });
  });

  group('RULE 10 -- application must not import presentation', () {
    test('flags a coordinator importing a controller', () {
      final violations = const LayerDependencyRule().check(
        contextFor(
          'lib/features/auth/application/coordinators/session_coordinator.dart',
          <String>[
            'lib/features/auth/presentation/controllers/login_controller.dart',
          ],
        ),
      );

      expect(violations, hasLength(1));
      expect(violations.single.rule, contains('RULE 10'));
    });

    test('flags Flutter in an application coordinator', () {
      final violations = const LayerDependencyRule().check(
        contextFor(
          'lib/features/auth/application/coordinators/session_coordinator.dart',
          const <String>[],
          packages: <String>['flutter'],
        ),
      );

      expect(violations, hasLength(1));
    });

    test('allows a coordinator using infrastructure abstractions', () {
      final violations = const LayerDependencyRule().check(
        contextFor(
          'lib/features/conversations/application/coordinators/outbox.dart',
          <String>['lib/infrastructure/database/daos/outbox_dao.dart'],
        ),
      );

      expect(violations, isEmpty);
    });
  });

  group('RULES 11-12 -- infrastructure stays business-agnostic', () {
    test('flags infrastructure importing a screen', () {
      final violations = const LayerDependencyRule().check(
        contextFor('lib/infrastructure/realtime/socket_manager.dart', <String>[
          'lib/features/auth/presentation/screens/login_screen.dart',
        ]),
      );

      expect(violations, isNotEmpty);
      expect(violations.first.rule, contains('RULE 11'));
    });

    test('flags infrastructure importing feature business code', () {
      final violations = const LayerDependencyRule().check(
        contextFor('lib/infrastructure/realtime/socket_manager.dart', <String>[
          'lib/features/conversations/domain/entities/message.dart',
        ]),
      );

      expect(violations, hasLength(1));
      expect(violations.single.rule, contains('RULE 12'));
    });

    test('allows the database to import feature table declarations', () {
      // The one documented exception: drift generates one schema for one
      // database, so the tables have to be declared on it. Moving every
      // feature's schema into infrastructure would be the worse violation.
      final violations = const LayerDependencyRule().check(
        contextFor('lib/infrastructure/database/app_database.dart', <String>[
          'lib/features/conversations/data/local/conversation_tables.dart',
          'lib/features/conversations/data/local/conversation_dao.dart',
        ]),
      );

      expect(violations, isEmpty);
    });

    test('the exception does not extend to other infrastructure files', () {
      final violations = const LayerDependencyRule().check(
        contextFor('lib/infrastructure/realtime/socket_client.dart', <String>[
          'lib/features/conversations/data/local/conversation_tables.dart',
        ]),
      );

      expect(violations, hasLength(1));
    });

    test('the exception does not extend to non-schema feature files', () {
      final violations = const LayerDependencyRule().check(
        contextFor('lib/infrastructure/database/app_database.dart', <String>[
          'lib/features/conversations/domain/services/message_service.dart',
        ]),
      );

      expect(violations, hasLength(1));
    });
  });

  group('RULE 18 -- the design system stays business-agnostic', () {
    test('flags a shared component importing a feature', () {
      final violations = const LayerDependencyRule().check(
        contextFor('lib/design_system/cards/app_card.dart', <String>[
          'lib/features/conversations/domain/entities/message.dart',
        ]),
      );

      expect(violations, hasLength(1));
      expect(violations.single.rule, contains('RULE 18'));
    });
  });

  group('RULE 31 -- features reach the design system through its barrel', () {
    test('flags a screen importing a component file directly', () {
      final violations = const DesignSystemBarrelRule().check(
        contextFor(
          'lib/features/conversations/presentation/screens/list.dart',
          <String>['lib/design_system/buttons/app_button.dart'],
        ),
      );

      expect(violations, hasLength(1));
      expect(violations.single.rule, contains('RULE 31'));
      expect(
        violations.single.allowedAlternative,
        contains('design_system.dart'),
      );
    });

    test('allows the barrel itself', () {
      final violations = const DesignSystemBarrelRule().check(
        contextFor(
          'lib/features/conversations/presentation/screens/list.dart',
          <String>['lib/design_system/design_system.dart'],
        ),
      );

      expect(violations, isEmpty);
    });

    test('leaves design-system files alone, which import each other by leaf', () {
      // The barrel must not import itself, so the rule cannot apply inside the
      // design system -- only features are held to it.
      final violations = const DesignSystemBarrelRule().check(
        contextFor('lib/design_system/feedback/error_state.dart', <String>[
          'lib/design_system/feedback/empty_state.dart',
        ]),
      );

      expect(violations, isEmpty);
    });
  });

  group('RULE 32 -- the design system sees app/theme/ and nothing else', () {
    test('flags a component reaching the dependency graph', () {
      final violations = const DesignSystemAppAccessRule().check(
        contextFor('lib/design_system/buttons/app_button.dart', <String>[
          'lib/app/bootstrap/dependencies.dart',
        ]),
      );

      expect(violations, hasLength(1));
      expect(violations.single.rule, contains('RULE 32'));
    });

    test('flags a component reaching the router', () {
      final violations = const DesignSystemAppAccessRule().check(
        contextFor('lib/design_system/cards/app_card.dart', <String>[
          'lib/app/router/routes.dart',
        ]),
      );

      expect(violations, hasLength(1));
    });

    test('allows the theme, which every component needs', () {
      final violations = const DesignSystemAppAccessRule().check(
        contextFor('lib/design_system/cards/app_card.dart', <String>[
          'lib/app/theme/theme.dart',
        ]),
      );

      expect(violations, isEmpty);
    });
  });

  group('RULE 33 -- the design system carries no application plumbing', () {
    test('flags a component importing a state management package', () {
      final violations = const DesignSystemPackageRule().check(
        contextFor(
          'lib/design_system/inputs/app_text_field.dart',
          <String>[],
          packages: <String>['flutter_riverpod'],
        ),
      );

      expect(violations, hasLength(1));
      expect(violations.single.rule, contains('RULE 33'));
      expect(violations.single.allowedAlternative, contains('callback'));
    });

    test('flags routing, networking and persistence alike', () {
      for (final package in <String>['go_router', 'dio', 'drift']) {
        final violations = const DesignSystemPackageRule().check(
          contextFor(
            'lib/design_system/cards/app_card.dart',
            <String>[],
            packages: <String>[package],
          ),
        );

        expect(violations, hasLength(1), reason: package);
      }
    });

    test('allows flutter and the icon set', () {
      final violations = const DesignSystemPackageRule().check(
        contextFor(
          'lib/design_system/display/badge.dart',
          <String>[],
          packages: <String>['flutter', 'lucide_icons_flutter'],
        ),
      );

      expect(violations, isEmpty);
    });

    test('holds only the design system to it', () {
      // A feature is entitled to all of these -- that is where they belong.
      final violations = const DesignSystemPackageRule().check(
        contextFor(
          'lib/features/auth/presentation/screens/login_screen.dart',
          <String>[],
          packages: <String>['flutter_riverpod', 'go_router'],
        ),
      );

      expect(violations, isEmpty);
    });
  });

  group('RULE 34 -- no raw design values outside the design system', () {
    const String screen =
        'lib/features/conversations/presentation/screens/list.dart';

    List<Violation> check(String source, {String path = screen}) =>
        const RawDesignValueRule().check(
          contextFor(path, <String>[], source: source),
        );

    test('flags a colour literal and a palette colour, on their lines', () {
      final violations = check(
        'final a = 1;\n'
        'final b = Color(0xFF112233);\n'
        'final c = Colors.red;\n',
      );

      expect(violations, hasLength(2));
      expect(violations.first.rule, contains('RULE 34'));
      expect(violations.map((Violation v) => v.line), <int>[2, 3]);
      expect(violations.first.forbiddenDependency, 'Color(0xFF112233)');
      expect(violations.first.allowedAlternative, contains('context.colors'));
    });

    test('flags a hand-set font size or family', () {
      expect(
        check("const TextStyle(fontSize: 14, fontFamily: 'Tajawal');"),
        hasLength(2),
      );
    });

    test('flags a number where a spacing or radius token belongs', () {
      final violations = check(
        'EdgeInsets.all(16);\n'
        'EdgeInsetsDirectional.only(start: TajeerSpacing.md, end: 8);\n'
        'BorderRadius.circular(12);\n',
      );

      expect(violations.map((Violation v) => v.line), <int>[1, 2, 3]);
      expect(violations.first.allowedAlternative, contains('TajeerSpacing'));
      expect(violations.last.allowedAlternative, contains('TajeerRadii'));
    });

    test('allows the tokens themselves, and zero', () {
      expect(
        check(
          'EdgeInsets.all(TajeerSpacing.md);\n'
          'EdgeInsetsDirectional.symmetric(horizontal: TajeerSpacing.xl2);\n'
          'EdgeInsets.only(top: 0);\n'
          'BorderRadius.circular(0);\n'
          'final c = context.colors.surface;\n'
          'final s = context.type.labelSm;\n',
        ),
        isEmpty,
      );
    });

    test('reads code, not what a comment or a string says about it', () {
      expect(
        check(
          '/// Never write Color(0xFF000000) here.\n'
          "final hint = 'Colors.red and EdgeInsets.all(16)';\n"
          '// fontSize: 12\n',
        ),
        isEmpty,
      );
      // An interpolation is code, whatever quotes it sits between.
      expect(check(r"final s = '${Colors.red}';"), hasLength(1));
    });

    test('holds app/ to it, but not the theme or the design system', () {
      const String source = 'final c = Colors.red;';

      expect(
        check(source, path: 'lib/app/shell/authenticated_shell.dart'),
        hasLength(1),
      );
      expect(check(source, path: 'lib/app/theme/app_theme.dart'), isEmpty);
      expect(
        check(source, path: 'lib/design_system/display/badge.dart'),
        isEmpty,
      );
    });
  });

  group('RULE 35 -- no raw Material widget the design system wraps', () {
    const String form =
        'lib/features/auth/presentation/widgets/login_form.dart';

    List<Violation> check(String source, {String path = form}) =>
        const MaterialWidgetRule().check(
          contextFor(path, <String>[], source: source),
        );

    test('flags a raw Checkbox and names what to use instead', () {
      final violations = check(
        'Widget build() {\n'
        '  return Checkbox(value: true, onChanged: null);\n'
        '}\n',
      );

      expect(violations, hasLength(1));
      expect(violations.single.rule, contains('RULE 35'));
      expect(violations.single.line, 2);
      expect(violations.single.forbiddenDependency, 'Checkbox(');
      expect(violations.single.allowedAlternative, startsWith('AppCheckbox'));
    });

    test('sees through type arguments, named constructors and prefixes', () {
      final violations = check(
        'TextButton.icon(onPressed: null, label: x, icon: y);\n'
        'Radio<int>(value: 1);\n'
        'material.Card(child: x);\n'
        'const Divider();\n',
      );

      expect(violations.map((Violation v) => v.forbiddenDependency), <String>[
        'TextButton.icon(',
        'Radio<int>(',
        'Card(',
        'Divider(',
      ]);
    });

    test('reports a longer name as itself, not as its prefix', () {
      expect(
        check('RadioListTile(value: 1);').single.forbiddenDependency,
        'RadioListTile(',
      );
    });

    test('flags the functions that open a raw dialog, sheet or snackbar', () {
      final violations = check(
        'showDialog(context: context, builder: b);\n'
        'showModalBottomSheet<void>(context: context, builder: b);\n'
        'ScaffoldMessenger.of(context).showSnackBar(bar);\n',
      );

      expect(violations.map((Violation v) => v.line), <int>[1, 2, 3]);
      expect(violations.first.allowedAlternative, contains('AppDialog'));
    });

    test("allows the design system, a lookup, and Dart's own switch", () {
      expect(
        check(
          'AppCheckbox(value: true, onChanged: null);\n'
          'AppCard(child: x);\n'
          'AppButton.icon(icon: i, onPressed: null);\n'
          'Scaffold.of(context);\n'
          'switch (value) { case 1: break; }\n'
          'final ChipThemeData theme = t;\n',
        ),
        isEmpty,
      );
    });

    test('reads code, not comments or strings', () {
      expect(
        check(
          '/// It used to wrap a raw Checkbox( here.\n'
          "final hint = 'use a TextField( instead';\n",
        ),
        isEmpty,
      );
    });

    test('leaves the design system alone, which is what wraps them', () {
      expect(
        check(
          'Checkbox(value: true, onChanged: null);',
          path: 'lib/design_system/inputs/app_checkbox.dart',
        ),
        isEmpty,
      );
    });
  });

  group('RULE 36 -- HTTP is reached only where its policy is reviewed', () {
    const String client = 'lib/infrastructure/network/http_client.dart';

    List<Violation> check(
      String path, {
      List<String> imports = const <String>[],
      List<String> packages = const <String>[],
    }) => const HttpTransportRule().check(
      contextFor(path, imports, packages: packages),
    );

    test('a feature data source may use the HTTP client', () {
      expect(
        check(
          'lib/features/customers/data/remote/customer_remote_data_source.dart',
          imports: <String>[client],
        ),
        isEmpty,
      );
    });

    test('a controller, a repository or a coordinator may not', () {
      for (final String path in <String>[
        'lib/features/customers/presentation/controllers/customers_controller.dart',
        'lib/features/customers/data/repositories/customer_repository_impl.dart',
        'lib/features/customers/application/coordinators/customer_sync.dart',
      ]) {
        final violations = check(path, imports: <String>[client]);

        expect(violations, hasLength(1), reason: path);
        expect(violations.single.rule, contains('RULE 36'));
      }
    });

    test('the composition root and the network layer may', () {
      expect(
        check('lib/app/bootstrap/dependencies.dart', imports: <String>[client]),
        isEmpty,
      );
      expect(
        check(
          'lib/infrastructure/network/interceptors/logging_interceptor.dart',
          packages: <String>['dio'],
        ),
        isEmpty,
      );
    });

    test('nothing outside the network layer names the HTTP library', () {
      final violations = check(
        'lib/features/auth/data/remote/auth_remote_data_source.dart',
        packages: <String>['cookie_jar', 'dio'],
      );

      // Not even a data source: it calls HttpClient, and never builds a Dio
      // or reads a cookie jar of its own.
      expect(violations, hasLength(2));
      expect(violations.first.allowedAlternative, contains('HttpClient'));
    });
  });

  group('RULES 13-15 -- feature boundaries', () {
    test('flags feature A importing feature B presentation', () {
      final violations = const FeatureBoundaryRule().check(
        contextFor(
          'lib/features/conversations/presentation/screens/list.dart',
          <String>[
            'lib/features/auth/presentation/controllers/auth_controller.dart',
          ],
        ),
      );

      expect(violations, hasLength(1));
      expect(violations.single.rule, contains('RULE 13'));
    });

    test('flags feature A importing feature B data', () {
      final violations = const FeatureBoundaryRule().check(
        contextFor(
          'lib/features/conversations/data/repositories/x.dart',
          <String>[
            'lib/features/auth/data/repositories/auth_repository_impl.dart',
          ],
        ),
      );

      expect(violations.single.rule, contains('RULE 14'));
    });

    test('flags feature A importing feature B realtime internals', () {
      final violations = const FeatureBoundaryRule().check(
        contextFor('lib/features/conversations/realtime/handler.dart', <String>[
          'lib/features/auth/realtime/auth_socket_credentials.dart',
        ]),
      );

      expect(violations.single.rule, contains('RULE 15'));
    });

    test('flags feature A importing feature B domain', () {
      // Even the domain is internal: a shared entity between features is a
      // contract decision, not something to reach for.
      final violations = const FeatureBoundaryRule().check(
        contextFor(
          'lib/features/conversations/domain/services/x.dart',
          <String>['lib/features/auth/domain/entities/user.dart'],
        ),
      );

      expect(violations, hasLength(1));
    });

    test('allows the published application contract', () {
      final violations = const FeatureBoundaryRule().check(
        contextFor(
          'lib/features/conversations/presentation/controllers/list.dart',
          <String>[
            'lib/features/auth/application/contracts/session_capability.dart',
          ],
        ),
      );

      expect(violations, isEmpty);
    });

    test('allows a feature importing itself', () {
      final violations = const FeatureBoundaryRule().check(
        contextFor(
          'lib/features/auth/presentation/screens/login_screen.dart',
          <String>['lib/features/auth/domain/services/auth_service.dart'],
        ),
      );

      expect(violations, isEmpty);
    });

    test('RULE 30 -- applies to a feature that does not exist yet', () {
      // Nothing in the rule enumerates features, so one added next year is
      // checked by the same code with no edit.
      final violations = const FeatureBoundaryRule().check(
        contextFor(
          'lib/features/orders/presentation/screens/order_screen.dart',
          <String>['lib/features/customers/data/repositories/impl.dart'],
        ),
      );

      expect(violations, hasLength(1));
      expect(violations.single.rule, contains('RULE 14'));
    });
  });

  group('RULES 3-5, 16-18 -- presentation access', () {
    test('flags a widget importing drift', () {
      final violations = const PresentationAccessRule().check(
        contextFor(
          'lib/features/conversations/presentation/widgets/bubble.dart',
          const <String>[],
          packages: <String>['drift'],
        ),
      );

      expect(violations, hasLength(1));
    });

    test('flags a controller importing the socket client package', () {
      final violations = const PresentationAccessRule().check(
        contextFor(
          'lib/features/conversations/presentation/controllers/thread.dart',
          const <String>[],
          packages: <String>['socket_io_client'],
        ),
      );

      expect(violations, hasLength(1));
    });

    test('flags a controller importing a DAO', () {
      final violations = const PresentationAccessRule().check(
        contextFor(
          'lib/features/conversations/presentation/controllers/thread.dart',
          <String>[
            'lib/features/conversations/data/local/conversation_dao.dart',
          ],
        ),
      );

      expect(violations, isNotEmpty);
    });

    test('flags a screen importing a repository interface', () {
      final violations = const PresentationAccessRule().check(
        contextFor(
          'lib/features/conversations/presentation/screens/thread.dart',
          <String>[
            'lib/features/conversations/domain/repositories/message_repository.dart',
          ],
        ),
      );

      expect(violations, isNotEmpty);
      expect(violations.first.rule, contains('RULE 18'));
    });

    test('allows a controller to hold a repository interface', () {
      // A controller sequencing a call is doing its job; a widget doing it
      // from the build tree is not.
      final violations = const PresentationAccessRule().check(
        contextFor(
          'lib/features/conversations/presentation/controllers/thread.dart',
          <String>[
            'lib/features/conversations/domain/repositories/message_repository.dart',
          ],
        ),
      );

      expect(violations, isEmpty);
    });
  });

  group('RULE 27 -- infrastructure exceptions stay contained', () {
    test('flags a controller importing the socket exception', () {
      final violations = const InfrastructureRule().check(
        contextFor(
          'lib/features/conversations/presentation/controllers/thread.dart',
          <String>['lib/infrastructure/realtime/socket_exception.dart'],
        ),
      );

      expect(violations, hasLength(1));
    });

    test('flags a domain service importing the HTTP exception', () {
      final violations = const InfrastructureRule().check(
        contextFor(
          'lib/features/auth/domain/services/auth_service.dart',
          <String>['lib/infrastructure/network/http_exception.dart'],
        ),
      );

      expect(violations, hasLength(1));
    });

    test('allows the data layer to translate them', () {
      final violations = const InfrastructureRule().check(
        contextFor(
          'lib/features/auth/data/repositories/auth_repository_impl.dart',
          <String>['lib/infrastructure/network/http_exception.dart'],
        ),
      );

      expect(violations, isEmpty);
    });

    test('flags Dio in an application coordinator', () {
      final violations = const InfrastructureRule().check(
        contextFor(
          'lib/features/conversations/application/coordinators/outbox.dart',
          const <String>[],
          packages: <String>['dio'],
        ),
      );

      expect(violations, hasLength(1));
    });
  });

  group('RULE 28 -- generated code is no bypass', () {
    test('flags generated output crossing a feature boundary', () {
      final violations = const GeneratedCodeRule().check(
        contextFor(
          'lib/features/conversations/presentation/controllers/x.g.dart',
          <String>['lib/features/auth/data/repositories/impl.dart'],
        ),
      );

      expect(violations, hasLength(1));
      expect(violations.single.rule, contains('RULE 28'));
    });

    test('allows generated output reaching a published contract', () {
      final violations = const GeneratedCodeRule().check(
        contextFor(
          'lib/features/conversations/presentation/controllers/x.g.dart',
          <String>[
            'lib/features/auth/application/contracts/session_capability.dart',
          ],
        ),
      );

      expect(violations, isEmpty);
    });

    test('ignores hand-written files', () {
      final violations = const GeneratedCodeRule().check(
        contextFor(
          'lib/features/conversations/presentation/controllers/x.dart',
          <String>['lib/features/auth/data/repositories/impl.dart'],
        ),
      );

      // Caught by FeatureBoundaryRule instead; this rule is only about
      // generated output.
      expect(violations, isEmpty);
    });
  });

  group('RULES 19-23 -- forbidden directories', () {
    test('flags core/, shared/, helpers/, utils/', () {
      const rule = ForbiddenDirectoryRule();

      for (final directory in <String>['core', 'shared', 'helpers', 'utils']) {
        final violations = rule.checkProject(<FileLocation>[
          PathClassifier.classify('lib/$directory/thing.dart'),
        ]);

        expect(violations, hasLength(1), reason: directory);
      }
    });

    test('flags a generic presentation/providers/ folder', () {
      final violations = const ForbiddenDirectoryRule().checkProject(
        <FileLocation>[
          PathClassifier.classify(
            'lib/features/auth/presentation/providers/auth_providers.dart',
          ),
        ],
      );

      expect(violations, hasLength(1));
      expect(violations.single.rule, contains('RULE 21'));
    });

    test('reports one violation per directory, not per file', () {
      final violations = const ForbiddenDirectoryRule().checkProject(
        <FileLocation>[
          PathClassifier.classify('lib/shared/a.dart'),
          PathClassifier.classify('lib/shared/b.dart'),
          PathClassifier.classify('lib/shared/c.dart'),
        ],
      );

      expect(violations, hasLength(1));
    });

    test('allows the real structure', () {
      final violations = const ForbiddenDirectoryRule().checkProject(
        <FileLocation>[
          PathClassifier.classify('lib/app/app.dart'),
          PathClassifier.classify('lib/design_system/display/badge.dart'),
          PathClassifier.classify('lib/failures/app_failure.dart'),
          PathClassifier.classify(
            'lib/features/auth/domain/services/auth_service.dart',
          ),
        ],
      );

      expect(violations, isEmpty);
    });
  });

  group('the failure taxonomy must depend on nothing', () {
    test('flags a package import', () {
      final violations = const ForbiddenDirectoryRule().checkFailuresPurity(
        contextFor(
          'lib/failures/app_failure.dart',
          const <String>[],
          packages: <String>['flutter'],
        ),
      );

      expect(violations, hasLength(1));
    });

    test('flags a project import outside failures/', () {
      // Every layer may import it, so anything it imports reaches the domain
      // too -- which is how a permitted kernel becomes the shared/ dumping
      // ground rule 20 forbids.
      final violations = const ForbiddenDirectoryRule().checkFailuresPurity(
        contextFor('lib/failures/app_failure.dart', <String>[
          'lib/infrastructure/logging/logger.dart',
        ]),
      );

      expect(violations, hasLength(1));
    });

    test('allows an import within failures/', () {
      final violations = const ForbiddenDirectoryRule().checkFailuresPurity(
        contextFor('lib/failures/app_failure.dart', <String>[
          'lib/failures/other.dart',
        ]),
      );

      expect(violations, isEmpty);
    });

    test('ignores files outside failures/', () {
      final violations = const ForbiddenDirectoryRule().checkFailuresPurity(
        contextFor(
          'lib/app/app.dart',
          const <String>[],
          packages: <String>['flutter'],
        ),
      );

      expect(violations, isEmpty);
    });
  });

  group('violation reporting', () {
    test('prints every field the format requires', () {
      const violation = Violation(
        rule: 'RULE 14 - Features must not import another feature\'s data.',
        source: 'lib/features/a/presentation/screens/x.dart',
        forbiddenDependency: 'lib/features/b/data/repositories/impl.dart',
        reason: 'Coupled to the implementation.',
        allowedAlternative: 'Use an application contract.',
        line: 12,
      );

      final report = violation.format();

      expect(report, contains('ARCHITECTURE VIOLATION'));
      expect(report, contains('Rule:'));
      expect(report, contains('Source:'));
      expect(report, contains('Forbidden dependency:'));
      expect(report, contains('Reason:'));
      expect(report, contains('Allowed alternative:'));

      // The line number makes the report navigable from a terminal.
      expect(report, contains('x.dart:12'));
    });

    test('omits the line when there is none', () {
      const violation = Violation(
        rule: 'RULE 20 - shared/ is forbidden.',
        source: 'lib/shared',
        forbiddenDependency: 'lib/shared/',
        reason: 'No architectural responsibility.',
        allowedAlternative: 'Move each file to its owning layer.',
      );

      expect(violation.format(), contains('lib/shared\n'));
    });
  });
}
