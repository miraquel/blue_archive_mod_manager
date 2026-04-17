import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bamm/features/game_data/application/backup_controller.dart';
import 'package:bamm/features/game_data/application/game_install_controller.dart';
import 'package:bamm/features/game_data/application/game_install_state.dart';
import 'package:bamm/features/game_data/domain/entities/backup_entry.dart';
import 'package:bamm/features/game_data/domain/repositories/game_data_repository.dart';
import 'package:bamm/features/game_data/infrastructure/android_game_data_repository.dart';
import 'package:bamm/features/shizuku/application/providers.dart';

/// Provides the [GameDataRepository] backed by the Shizuku bridge.
final gameDataRepositoryProvider = Provider<GameDataRepository>((ref) {
  final bridge = ref.watch(shizukuBridgeProvider);
  return AndroidGameDataRepository(bridge);
});

/// Provides the [GameInstallController] and its [GameInstallState].
final gameInstallControllerProvider =
    AsyncNotifierProvider<GameInstallController, GameInstallState>(
  GameInstallController.new,
);

/// Provides the [BackupController] and the list of [BackupEntry]s.
final backupControllerProvider =
    AsyncNotifierProvider<BackupController, List<BackupEntry>>(
  BackupController.new,
);
