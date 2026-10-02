import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../../../failures/app_failure.dart';
import '../../domain/entities/conversation_note.dart';

part 'conversation_record_controller.g.dart';

/// A thread's record, from the local database. Oldest first.
@riverpod
Stream<List<ConversationNote>> threadRecord(Ref ref, String conversationId) {
  return ref
      .watch(conversationRecordRepositoryProvider)
      .watchNotes(conversationId);
}

/// Brings the record up to date. Fires once per thread while it is open and
/// fails quietly: what is stored stays on screen.
@riverpod
Future<void> threadRecordRefresh(Ref ref, String conversationId) async {
  try {
    await ref
        .read(conversationRecordRepositoryProvider)
        .synchronizeNotes(conversationId);
  } on AppFailure {
    // Offline, throttled, or a server error. The local copy stands.
  }
}

/// What the record's two actions are doing right now.
final class RecordActionState {
  const RecordActionState({
    this.isSavingNote = false,
    this.isSummarizing = false,
    this.outcome,
  });

  final bool isSavingNote;
  final bool isSummarizing;

  /// The last thing worth telling the member, consumed by the screen.
  final RecordOutcome? outcome;

  RecordActionState copyWith({
    bool? isSavingNote,
    bool? isSummarizing,
    RecordOutcome? outcome,
    bool clearOutcome = false,
  }) {
    return RecordActionState(
      isSavingNote: isSavingNote ?? this.isSavingNote,
      isSummarizing: isSummarizing ?? this.isSummarizing,
      outcome: clearOutcome ? null : (outcome ?? this.outcome),
    );
  }
}

enum RecordOutcome { noteSaved, noteFailed, summaryDone, summaryFailed }

/// The two things a member does to a thread's record: write a note the
/// customer never sees, and ask the assistant to summarise.
///
/// Both are online-only, and the controller says so through [RecordOutcome]
/// rather than through a thrown error: the composer stays usable either way,
/// and the screen decides how to word it.
@riverpod
class ConversationRecordController extends _$ConversationRecordController {
  @override
  RecordActionState build(String conversationId) => const RecordActionState();

  Future<void> addNote(String body) async {
    final String text = body.trim();
    if (text.isEmpty || state.isSavingNote) return;

    state = state.copyWith(isSavingNote: true, clearOutcome: true);
    try {
      await ref
          .read(conversationRecordRepositoryProvider)
          .addNote(conversationId, text);
      state = state.copyWith(
        isSavingNote: false,
        outcome: RecordOutcome.noteSaved,
      );
    } on AppFailure {
      state = state.copyWith(
        isSavingNote: false,
        outcome: RecordOutcome.noteFailed,
      );
    }
  }

  Future<void> summarize() async {
    if (state.isSummarizing) return;

    state = state.copyWith(isSummarizing: true, clearOutcome: true);
    try {
      await ref
          .read(conversationRecordRepositoryProvider)
          .summarize(conversationId);
      state = state.copyWith(
        isSummarizing: false,
        outcome: RecordOutcome.summaryDone,
      );
    } on AppFailure {
      state = state.copyWith(
        isSummarizing: false,
        outcome: RecordOutcome.summaryFailed,
      );
    }
  }

  void clearOutcome() => state = state.copyWith(clearOutcome: true);
}
