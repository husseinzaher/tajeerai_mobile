import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../application/state/sync_state.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/services/conversation_service.dart';

/// The rail's search term.
///
/// Its own provider so typing in the search field re-runs the local query
/// without rebuilding the controller or touching the network -- search here is
/// a filter over what is already on the device.
final NotifierProvider<ConversationSearchController, String>
conversationSearchProvider =
    NotifierProvider<ConversationSearchController, String>(
      ConversationSearchController.new,
    );

class ConversationSearchController extends Notifier<String> {
  @override
  String build() => '';

  void update(String term) => state = term;

  void clear() => state = '';
}

/// The Inbox rail.
///
/// **Reads the local database, never the network.** The stream comes from
/// `ConversationService`, which reads the repository's reactive query -- so
/// this emits offline, and it re-emits when the socket handler writes a row.
/// Synchronisation is somebody else's job; this screen does not know whether
/// the data arrived a second ago or last week.
final StreamProvider<List<Conversation>> conversationListProvider =
    StreamProvider<List<Conversation>>((ref) {
      final service = ref.watch(conversationServiceProvider);
      final search = ref.watch(conversationSearchProvider);

      return service.watchInbox(searchTerm: search.isEmpty ? null : search);
    });

/// The synchronisation banner's state.
///
/// Separate from the connection state on purpose: the UI has to be able to say
/// "connected, but still catching up".
final StreamProvider<ConversationSyncState> conversationSyncStateProvider =
    StreamProvider<ConversationSyncState>((ref) async* {
      final coordinator = ref.watch(conversationSyncProvider);

      yield coordinator.state;
      yield* coordinator.states;
    });

/// Actions the rail offers.
///
/// Deliberately thin. Sorting belongs to the domain service, syncing to the
/// coordinator; this exists so a widget has something to call that is not a
/// repository.
final Provider<ConversationListController> conversationListControllerProvider =
    Provider<ConversationListController>(ConversationListController.new);

class ConversationListController {
  ConversationListController(this._ref);

  final Ref _ref;

  /// Pull-to-refresh.
  ///
  /// An explicit, user-initiated sync -- the only place in the rail that
  /// causes a network call, and it still writes through the database rather
  /// than into the widget.
  Future<void> refresh() => _ref.read(conversationSyncProvider).synchronize();

  ConversationService get _service => _ref.read(conversationServiceProvider);

  /// Marks a thread read when it is opened.
  Future<void> markRead(Conversation conversation) =>
      _service.markRead(conversation);
}
