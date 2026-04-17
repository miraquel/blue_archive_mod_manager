import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bamm/features/game_data/application/providers.dart';
import 'package:bamm/features/game_data/domain/entities/backup_entry.dart';

/// Manages backup creation, restoration, and deletion.
class BackupController extends AsyncNotifier<List<BackupEntry>> {
  @override
  Future<List<BackupEntry>> build() async {
    final repo = ref.watch(gameDataRepositoryProvider);
    return repo.listBackups();
  }

  /// Create a backup of the game file at [gameFilePath].
  ///
  /// Returns the created [BackupEntry], or `null` if the operation failed.
  Future<BackupEntry?> createBackup(String gameFilePath) async {
    final repo = ref.read(gameDataRepositoryProvider);
    try {
      final entry = await repo.createBackup(gameFilePath);
      ref.invalidateSelf();
      await future;
      return entry;
    } on Exception {
      return null;
    }
  }

  /// Restore a [BackupEntry] to its original game data location.
  Future<bool> restoreBackup(BackupEntry entry) async {
    final repo = ref.read(gameDataRepositoryProvider);
    try {
      final success = await repo.restoreBackup(entry);
      return success;
    } on Exception {
      return false;
    }
  }

  /// Delete a backup from local storage.
  Future<void> deleteBackup(BackupEntry entry) async {
    final repo = ref.read(gameDataRepositoryProvider);
    await repo.deleteBackup(entry);
    ref.invalidateSelf();
    await future;
  }
}
