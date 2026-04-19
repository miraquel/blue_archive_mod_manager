import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bamm/core/constants/app_constants.dart';
import 'package:bamm/core/logging/app_logger.dart';
import 'package:bamm/features/game_data/application/providers.dart';
import 'package:bamm/features/mods/application/providers.dart';
import 'package:bamm/features/mods/domain/entities/mod_apply_result.dart';
import 'package:bamm/features/mods/domain/entities/mod_entry.dart';
import 'package:bamm/features/mods/domain/services/crc_patcher.dart';
import 'package:bamm/features/shizuku/application/providers.dart';

class ModApplyState {
  final bool isApplying;
  final String? currentModId;
  final String? statusMessage;
  final String? error;

  const ModApplyState({
    this.isApplying = false,
    this.currentModId,
    this.statusMessage,
    this.error,
  });

  ModApplyState copyWith({
    bool? isApplying,
    String? currentModId,
    String? statusMessage,
    String? error,
  }) {
    return ModApplyState(
      isApplying: isApplying ?? this.isApplying,
      currentModId: currentModId ?? this.currentModId,
      statusMessage: statusMessage ?? this.statusMessage,
      error: error ?? this.error,
    );
  }
}

class ModBatchActionResult {
  final int attemptedCount;
  final int successCount;
  final List<String> failedMods;

  const ModBatchActionResult({
    required this.attemptedCount,
    required this.successCount,
    this.failedMods = const [],
  });

  int get failureCount => failedMods.length;
}

class ModApplyController extends Notifier<ModApplyState> {
  static const _tag = 'ModApply';

  @override
  ModApplyState build() => const ModApplyState();

  /// Resolve the full device path for a target file name.
  Future<String> _resolveTargetPath(String targetFileName) async {
    final gameDataRepo = ref.read(gameDataRepositoryProvider);
    final installs = await gameDataRepo.detectInstallations();
    final accessible = installs
        .where((i) => i.region == GameRegion.global && i.isAccessible)
        .toList(growable: false);
    if (accessible.isEmpty) {
      throw StateError('No accessible Global Android installation found.');
    }
    return '${accessible.first.gameDataPath}/$targetFileName';
  }

  /// Apply a mod to its target game file.
  ///
  /// Steps:
  /// 1. Validate mod has a target file set
  /// 2. Read mod file from local storage
  /// 3. Read original game file via Shizuku
  /// 4. Create a backup of the original (if none exists for this path)
  /// 5. Use CRC patcher to match original CRC
  /// 6. Write patched file to game directory via Shizuku
  Future<ModApplyResult> applyMod(ModEntry mod) async {
    final targetFile = mod.targetFile.trim();

    if (state.isApplying) {
      return ModApplyResult(
        success: false,
        modId: mod.id,
        targetFile: targetFile,
        errorMessage: 'Another mod is currently being applied',
      );
    }

    if (targetFile.isEmpty) {
      return ModApplyResult(
        success: false,
        modId: mod.id,
        targetFile: '',
        errorMessage: 'No target file could be inferred for this mod',
      );
    }

    state = ModApplyState(
      isApplying: true,
      currentModId: mod.id,
      statusMessage: 'Reading mod file...',
    );

    try {
      // Read the mod file from local storage
      final modFile = File(mod.storagePath);
      if (!await modFile.exists()) {
        throw StateError('Mod file not found at: ${mod.storagePath}');
      }
      final modData = await modFile.readAsBytes();

      // Resolve full device path
      final fullTargetPath = await _resolveTargetPath(targetFile);

      // Read original game file via Shizuku
      state = state.copyWith(statusMessage: 'Reading original game file...');
      final bridge = ref.read(shizukuBridgeProvider);
      final originalData = await bridge.readFile(fullTargetPath);
      if (originalData == null) {
        throw StateError(
          'Could not read game file: $fullTargetPath',
        );
      }

      // Create backup before first write (skip if backup already exists)
      state = state.copyWith(statusMessage: 'Creating backup...');
      final backupController =
          ref.read(backupControllerProvider.notifier);
      final existingBackups =
          ref.read(backupControllerProvider).valueOrNull ?? [];
      final alreadyBackedUp = existingBackups.any(
        (b) => b.originalPath == fullTargetPath,
      );
      if (!alreadyBackedUp) {
        await backupController.createBackup(fullTargetPath);
        AppLogger.info(
          'Created backup for: $fullTargetPath',
          tag: _tag,
        );
      }

      // CRC patching
      state = state.copyWith(statusMessage: 'Patching CRC...');
      var crcPatched = false;
      var finalData = modData.toList();

      final patchResult = CrcPatcher.manipulateCrc(
        originalData: originalData,
        modData: modData,
      );
      if (patchResult.success && patchResult.patchedData != null) {
        finalData = patchResult.patchedData!;
        crcPatched = true;
      }

      // Write patched file to game directory via Shizuku
      state = state.copyWith(statusMessage: 'Writing to game directory...');
      final writeSuccess = await bridge.writeFile(fullTargetPath, finalData);
      if (!writeSuccess) {
        throw StateError('Failed to write file: $fullTargetPath');
      }

      // Mark mod as applied
      final repo = ref.read(modRepositoryProvider);
      final updatedMod = mod.copyWith(isApplied: true);
      await repo.updateMod(updatedMod);
      ref.invalidate(modLibraryControllerProvider);

      state = const ModApplyState();

      AppLogger.info(
        'Applied mod: ${mod.name} -> $targetFile (CRC patched: $crcPatched)',
        tag: _tag,
      );

      return ModApplyResult(
        success: true,
        modId: mod.id,
        targetFile: targetFile,
        crcPatched: crcPatched,
      );
    } catch (e, st) {
      AppLogger.error(
        'Failed to apply mod: ${mod.name}',
        tag: _tag,
        error: e,
        stackTrace: st,
      );

      state = ModApplyState(error: e.toString());

      return ModApplyResult(
        success: false,
        modId: mod.id,
        targetFile: targetFile,
        errorMessage: e.toString(),
      );
    }
  }

  /// Restore original file from backup.
  Future<bool> restoreMod(ModEntry mod) async {
    if (state.isApplying) return false;

    state = ModApplyState(
      isApplying: true,
      currentModId: mod.id,
      statusMessage: 'Restoring original file...',
    );

    try {
      final targetFile = mod.targetFile.trim();
      final fullTargetPath = await _resolveTargetPath(targetFile);

      // Find the backup for this file
      final backupController =
          ref.read(backupControllerProvider.notifier);
      final backups =
          ref.read(backupControllerProvider).valueOrNull ?? [];
      final backup = backups
          .where((b) => b.originalPath == fullTargetPath)
          .toList(growable: false);

      if (backup.isEmpty) {
        AppLogger.warning(
          'No backup found for $fullTargetPath — marking as unapplied',
          tag: _tag,
        );
      } else {
        // Restore the earliest backup (the true original)
        final earliest = backup.reduce(
          (a, b) => a.createdAt.isBefore(b.createdAt) ? a : b,
        );
        final ok = await backupController.restoreBackup(earliest);
        if (!ok) {
          throw StateError('Failed to restore backup for $fullTargetPath');
        }
        AppLogger.info(
          'Restored backup for: $fullTargetPath',
          tag: _tag,
        );
      }

      // Mark mod as unapplied
      final repo = ref.read(modRepositoryProvider);
      final updatedMod = mod.copyWith(isApplied: false);
      await repo.updateMod(updatedMod);
      ref.invalidate(modLibraryControllerProvider);

      state = const ModApplyState();

      AppLogger.info('Restored mod: ${mod.name}', tag: _tag);
      return true;
    } catch (e, st) {
      AppLogger.error(
        'Failed to restore mod: ${mod.name}',
        tag: _tag,
        error: e,
        stackTrace: st,
      );

      state = ModApplyState(error: e.toString());
      return false;
    }
  }

  Future<ModBatchActionResult> applyAllMods(List<ModEntry> mods) async {
    if (state.isApplying) {
      return const ModBatchActionResult(attemptedCount: 0, successCount: 0);
    }

    final pendingMods =
        mods.where((mod) => !mod.isApplied).toList(growable: false);
    if (pendingMods.isEmpty) {
      return const ModBatchActionResult(attemptedCount: 0, successCount: 0);
    }

    var successCount = 0;
    final failedMods = <String>[];

    for (final mod in pendingMods) {
      final result = await applyMod(mod);
      if (result.success) {
        successCount++;
      } else {
        failedMods.add(mod.name);
      }
    }

    return ModBatchActionResult(
      attemptedCount: pendingMods.length,
      successCount: successCount,
      failedMods: failedMods,
    );
  }

  Future<ModBatchActionResult> restoreAllMods(List<ModEntry> mods) async {
    if (state.isApplying) {
      return const ModBatchActionResult(attemptedCount: 0, successCount: 0);
    }

    final appliedMods =
        mods.where((mod) => mod.isApplied).toList(growable: false);
    if (appliedMods.isEmpty) {
      return const ModBatchActionResult(attemptedCount: 0, successCount: 0);
    }

    var successCount = 0;
    final failedMods = <String>[];

    for (final mod in appliedMods) {
      final success = await restoreMod(mod);
      if (success) {
        successCount++;
      } else {
        failedMods.add(mod.name);
      }
    }

    return ModBatchActionResult(
      attemptedCount: appliedMods.length,
      successCount: successCount,
      failedMods: failedMods,
    );
  }

  void clearError() {
    if (state.error != null) {
      state = const ModApplyState();
    }
  }
}
