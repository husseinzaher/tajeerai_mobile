import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../application/ports/caller_id_platform_port.dart';
import '../../domain/entities/caller_id_settings.dart';

final class CallerIdSettingsViewState {
  const CallerIdSettingsViewState({
    this.settings = const CallerIdSettings(),
    this.permissions = const CallerIdPermissionStatus(
      callScreeningRoleHeld: false,
      canDrawOverlays: false,
      callScreeningAvailable: false,
    ),
    this.isLoading = true,
    this.isSaving = false,
  });

  final CallerIdSettings settings;
  final CallerIdPermissionStatus permissions;
  final bool isLoading;
  final bool isSaving;

  CallerIdSettingsViewState copyWith({
    CallerIdSettings? settings,
    CallerIdPermissionStatus? permissions,
    bool? isLoading,
    bool? isSaving,
  }) {
    return CallerIdSettingsViewState(
      settings: settings ?? this.settings,
      permissions: permissions ?? this.permissions,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

final NotifierProvider<CallerIdSettingsController, CallerIdSettingsViewState>
callerIdSettingsControllerProvider =
    NotifierProvider<CallerIdSettingsController, CallerIdSettingsViewState>(
      CallerIdSettingsController.new,
    );

class CallerIdSettingsController extends Notifier<CallerIdSettingsViewState> {
  @override
  CallerIdSettingsViewState build() {
    // Deferred, not called inline: `refresh` writes `state` on its first
    // line, and a Notifier's state does not exist until `build` has
    // returned. Called synchronously it threw before the first await, the
    // failed future was discarded, and the screen sat on its spinner forever.
    Future<void>.microtask(refresh);

    return const CallerIdSettingsViewState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);

    final settings = await ref.read(callerIdSettingsCoordinatorProvider).read();

    // A permission read that fails - the platform channel not answering, a
    // device without the role manager - must not leave the screen on its
    // spinner forever: the settings still have to be reachable, and "not
    // granted" is the honest state to show until the read works.
    CallerIdPermissionStatus permissions = state.permissions;
    try {
      permissions = await ref
          .read(callerIdSettingsCoordinatorProvider)
          .permissionStatus();
    } on Object {
      // Shown as not granted; the next refresh asks again.
    }

    state = state.copyWith(
      settings: settings,
      permissions: permissions,
      isLoading: false,
    );
  }

  Future<void> updateSettings(CallerIdSettings settings) async {
    state = state.copyWith(isSaving: true);

    final saved = await ref
        .read(callerIdSettingsCoordinatorProvider)
        .save(settings);

    state = state.copyWith(settings: saved, isSaving: false);
  }

  Future<void> requestCallScreeningRole() async {
    await ref
        .read(callerIdSettingsCoordinatorProvider)
        .requestCallScreeningRole();
    await refresh();
  }

  Future<void> openOverlaySettings() async {
    await ref.read(callerIdSettingsCoordinatorProvider).openOverlaySettings();
    await refresh();
  }

  Future<void> requestContactsPermission() async {
    await ref
        .read(callerIdSettingsCoordinatorProvider)
        .requestContactsPermission();
    await refresh();
  }

  Future<void> requestPhoneStatePermission() async {
    await ref
        .read(callerIdSettingsCoordinatorProvider)
        .requestPhoneStatePermission();
    await refresh();
  }
}
