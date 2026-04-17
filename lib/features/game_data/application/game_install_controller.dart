import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bamm/core/constants/app_constants.dart';
import 'package:bamm/features/game_data/application/game_install_state.dart';
import 'package:bamm/features/game_data/application/providers.dart';

/// Manages detection and selection of Blue Archive installations.
class GameInstallController extends AsyncNotifier<GameInstallState> {
  @override
  Future<GameInstallState> build() async {
    return const GameInstallState();
  }

  /// Scan the device for installed Blue Archive versions.
  Future<void> detectInstallations() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(gameDataRepositoryProvider);
      final installs = await repo.detectInstallations();
      return GameInstallState(
        installations: installs,
        selectedRegion: installs.isNotEmpty ? installs.first.region : null,
      );
    });
  }

  /// Select a specific [region] from the detected installations.
  void selectRegion(GameRegion region) {
    final current = state.valueOrNull;
    if (current == null) return;

    final hasRegion = current.installations.any((i) => i.region == region);
    if (!hasRegion) return;

    state = AsyncValue.data(current.copyWith(selectedRegion: region));
  }
}
