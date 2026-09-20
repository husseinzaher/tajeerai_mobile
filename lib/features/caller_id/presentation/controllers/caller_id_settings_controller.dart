import 'dart:async';

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
    unawaited(refresh());

    return const CallerIdSettingsViewState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);

    final settings = await ref.read(callerIdSettingsCoordinatorProvider).read();
    final permissions = await ref
        .read(callerIdSettingsCoordinatorProvider)
        .permissionStatus();

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
    await ref.read(callerIdSettingsCoordinatorProvider).requestCallScreeningRole();
    await refresh();
  }

  Future<void> openOverlaySettings() async {
    await ref.read(callerIdSettingsCoordinatorProvider).openOverlaySettings();
    await refresh();
  }
}
