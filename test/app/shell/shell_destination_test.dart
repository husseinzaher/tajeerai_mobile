import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/router/routes.dart';
import 'package:tajeerai_mobile/app/shell/shell_destination.dart';
import 'package:tajeerai_mobile/features/auth/domain/entities/user.dart';

AuthenticatedUser _holding(
  Set<String> permissions, {
  Set<String> denied = const <String>{},
}) {
  return AuthenticatedUser(
    id: 'u1',
    name: 'Ada',
    email: 'ada@demo.test',
    role: 'member',
    locale: 'ar',
    permissions: permissions,
    denied: denied,
  );
}

void main() {
  group('isOpenTo', () {
    test('a member holding the permission is offered the destination', () {
      expect(
        ShellDestination.inbox.isOpenTo(
          _holding(<String>{'read:Conversation'}),
        ),
        isTrue,
      );
    });

    test('so is an owner, through manage:all', () {
      expect(
        ShellDestination.inbox.isOpenTo(_holding(<String>{'manage:all'})),
        isTrue,
      );
    });

    test('a member without it is not', () {
      expect(
        ShellDestination.inbox.isOpenTo(_holding(<String>{'read:Customer'})),
        isFalse,
      );
    });

    test('nor is an owner it was denied to', () {
      expect(
        ShellDestination.inbox.isOpenTo(
          _holding(
            <String>{'manage:all'},
            denied: <String>{'read:Conversation'},
          ),
        ),
        isFalse,
      );
    });
  });

  group('where a location belongs', () {
    test('a destination covers where it starts and everything under it', () {
      expect(ShellDestination.inbox.covers(AppRoutes.conversations), isTrue);
      expect(
        ShellDestination.inbox.covers(AppRoutes.conversationDetailPath('c1')),
        isTrue,
      );
    });

    test('but not a path that only begins with the same letters', () {
      expect(
        ShellDestination.inbox.covers('${AppRoutes.conversations}-archive'),
        isFalse,
      );
    });

    test('containing names the destination, or nothing outside the shell', () {
      expect(
        ShellDestination.containing(AppRoutes.conversationDetailPath('c1')),
        ShellDestination.inbox,
      );
      expect(ShellDestination.containing(AppRoutes.login), isNull);
    });
  });

  group('homeFor', () {
    test('is the first destination open to the member', () {
      expect(
        ShellDestination.homeFor(_holding(<String>{'manage:all'})),
        ShellDestination.inbox,
      );
    });

    test('is still the first destination when none is open', () {
      expect(
        ShellDestination.homeFor(_holding(const <String>{})),
        ShellDestination.values.first,
      );
    });
  });
}
