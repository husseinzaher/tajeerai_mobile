import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/design_system/messaging/message_data.dart';
import 'package:tajeerai_mobile/design_system/messaging/timeline_builder.dart';

AppMessageData _message(
  String id,
  DateTime at, {
  AppMessageSide side = AppMessageSide.incoming,
  String? author,
  AppMessageKind kind = AppMessageKind.text,
  bool bot = false,
}) => AppMessageData(
  id: id,
  side: side,
  sentAt: at,
  kind: kind,
  text: id,
  authorId: author,
  isFromBot: bot,
);

/// What the builder produced, as something a person can read in a failure:
/// `day 3/12`, `unread 2`, and message ids with `(` where a run starts and `)`
/// where it ends.
List<String> _shape(List<AppTimelineEntry> entries) => <String>[
  for (final AppTimelineEntry entry in entries)
    switch (entry) {
      AppTimelineDay(:final DateTime day) => 'day ${day.month}/${day.day}',
      AppTimelineUnread(:final int count) => 'unread $count',
      AppTimelineMessage(
        :final AppMessageData message,
        :final bool startsRun,
        :final bool endsRun,
      ) =>
        '${startsRun ? '(' : ''}${message.id}${endsRun ? ')' : ''}',
    },
];

DateTime _at(int day, int hour, int minute) =>
    DateTime(2026, 3, day, hour, minute);

void main() {
  test('an empty thread draws nothing', () {
    expect(AppTimelineBuilder.build(<AppMessageData>[]), isEmpty);
  });

  test('one message is a day and a run of one', () {
    expect(
      _shape(
        AppTimelineBuilder.build(<AppMessageData>[
          _message('m1', _at(12, 9, 0)),
        ]),
      ),
      <String>['day 3/12', '(m1)'],
    );
  });

  test('a burst from one author is one run', () {
    expect(
      _shape(
        AppTimelineBuilder.build(<AppMessageData>[
          _message('m1', _at(12, 9, 0)),
          _message('m2', _at(12, 9, 2)),
          _message('m3', _at(12, 9, 4)),
        ]),
      ),
      <String>['day 3/12', '(m1', 'm2', 'm3)'],
    );
  });

  test('the window is inclusive, and a longer gap starts a new run', () {
    expect(
      _shape(
        AppTimelineBuilder.build(<AppMessageData>[
          _message('m1', _at(12, 9, 0)),
          _message('m2', _at(12, 9, 5)),
          _message('m3', _at(12, 9, 11)),
        ]),
      ),
      <String>['day 3/12', '(m1', 'm2)', '(m3)'],
    );
  });

  test('the other side, another author, or the assistant starts a run', () {
    expect(
      _shape(
        AppTimelineBuilder.build(<AppMessageData>[
          _message('m1', _at(12, 9, 0)),
          _message(
            'm2',
            _at(12, 9, 1),
            side: AppMessageSide.outgoing,
            author: 'a1',
          ),
          _message(
            'm3',
            _at(12, 9, 1),
            side: AppMessageSide.outgoing,
            author: 'a2',
          ),
          _message(
            'm4',
            _at(12, 9, 2),
            side: AppMessageSide.outgoing,
            author: 'a2',
            bot: true,
          ),
        ]),
      ),
      <String>['day 3/12', '(m1)', '(m2)', '(m3)', '(m4)'],
    );
  });

  test('a system line is never part of a run', () {
    expect(
      _shape(
        AppTimelineBuilder.build(<AppMessageData>[
          _message('m1', _at(12, 9, 0)),
          _message('s1', _at(12, 9, 1), kind: AppMessageKind.system),
          _message('m2', _at(12, 9, 2)),
        ]),
      ),
      <String>['day 3/12', '(m1)', '(s1)', '(m2)'],
    );
  });

  test('a thread of nothing but system lines is still drawable', () {
    expect(
      _shape(
        AppTimelineBuilder.build(<AppMessageData>[
          _message('s1', _at(12, 9, 0), kind: AppMessageKind.system),
          _message('s2', _at(12, 9, 0), kind: AppMessageKind.system),
        ], unreadCount: 3),
      ),
      <String>['day 3/12', '(s1)', '(s2)'],
    );
  });

  test('midnight starts a new day, and the new day breaks the run', () {
    expect(
      _shape(
        AppTimelineBuilder.build(<AppMessageData>[
          _message('m1', _at(11, 23, 58)),
          _message('m2', _at(12, 0, 1)),
        ]),
      ),
      <String>['day 3/11', '(m1)', 'day 3/12', '(m2)'],
    );
  });

  test('the turn of a year is a day boundary like any other', () {
    expect(
      _shape(
        AppTimelineBuilder.build(<AppMessageData>[
          _message('m1', DateTime(2025, 12, 31, 23, 59)),
          _message('m2', DateTime(2026, 1, 1, 0, 0)),
        ]),
      ),
      <String>['day 12/31', '(m1)', 'day 1/1', '(m2)'],
    );
  });

  group('the unread marker', () {
    test('sits before the oldest unread message, splitting its run', () {
      expect(
        _shape(
          AppTimelineBuilder.build(<AppMessageData>[
            _message('m1', _at(12, 9, 0)),
            _message('m2', _at(12, 9, 1)),
            _message('m3', _at(12, 9, 2)),
            _message('m4', _at(12, 9, 3)),
          ], unreadCount: 2),
        ),
        <String>['day 3/12', '(m1', 'm2)', 'unread 2', '(m3', 'm4)'],
      );
    });

    test('counts only incoming messages, never ours or system lines', () {
      expect(
        _shape(
          AppTimelineBuilder.build(<AppMessageData>[
            _message('m1', _at(12, 9, 0)),
            _message('m2', _at(12, 9, 1), side: AppMessageSide.outgoing),
            _message('m3', _at(12, 9, 2)),
            _message('s1', _at(12, 9, 3), kind: AppMessageKind.system),
          ], unreadCount: 2),
        ),
        <String>['day 3/12', 'unread 2', '(m1)', '(m2)', '(m3)', '(s1)'],
      );
    });

    test('goes to the very start when everything on the device is unread', () {
      expect(
        _shape(
          AppTimelineBuilder.build(<AppMessageData>[
            _message('m1', _at(12, 9, 0)),
            _message('m2', _at(12, 9, 1)),
          ], unreadCount: 5),
        ),
        <String>['day 3/12', 'unread 5', '(m1', 'm2)'],
      );
    });

    test('follows the day heading when both fall on one message', () {
      expect(
        _shape(
          AppTimelineBuilder.build(<AppMessageData>[
            _message('m1', _at(11, 9, 0)),
            _message('m2', _at(12, 9, 0)),
          ], unreadCount: 1),
        ),
        <String>['day 3/11', '(m1)', 'day 3/12', 'unread 1', '(m2)'],
      );
    });

    test('is absent with nothing unread, or nothing incoming', () {
      final List<AppMessageData> ours = <AppMessageData>[
        _message('m1', _at(12, 9, 0), side: AppMessageSide.outgoing),
      ];

      expect(
        AppTimelineBuilder.build(<AppMessageData>[
          _message('m1', _at(12, 9, 0)),
        ]).whereType<AppTimelineUnread>(),
        isEmpty,
      );
      expect(
        AppTimelineBuilder.build(
          ours,
          unreadCount: 2,
        ).whereType<AppTimelineUnread>(),
        isEmpty,
      );
    });
  });
}
