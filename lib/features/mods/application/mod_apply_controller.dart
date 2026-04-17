import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bamm/core/logging/app_logger.dart';
import 'package:bamm/features/mods/application/providers.dart';
import 'package:bamm/features/mods/domain/entities/mod_apply_result.dart';
import 'package:bamm/features/mods/domain/entities/mod_entry.dart';
// ignore: unused_import
import 'package:bamm/features/mods/domain/services/crc_patcher.dart';

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

class ModApplyController extends Notifier<ModApplyState> {
  @override
  ModApplyState build() => const ModApplyState();

  /// Apply a mod to its target game file.
  ///
  /// Steps:
  /// 1. Validate mod has a target file set
  /// 2. Read mod file from local storage
  /// 3. Read original game file via Shizuku (when bridge is available)
  /// 4. Use CRC patcher to match original CRC
  /// 5. Write patched file to game directory via Shizuku
  Future<ModApplyResult> applyMod(ModEntry mod) async {
    if (state.isApplying) {
      return ModApplyResult(
        success: false,
        modId: mod.id,
        targetFile: mod.targetFile ?? '',
        errorMessage: 'Another mod is currently being applied',
      );
    }

    if (mod.targetFile == null) {
      return ModApplyResult(
        success: false,
        modId: mod.id,
        targetFile: '',
        errorMessage: 'No target file set for this mod',
      );
    }

    state = ModApplyState(
      isApplying: true,
      currentModId: mod.id,
      statusMessage: 'Reading mod file...',
    );

    try {
      // Read the mod file from local storage
      state = state.copyWith(statusMessage: 'Reading mod file...');
      final modFile = File(mod.storagePath);
      if (!await modFile.exists()) {
        throw StateError('Mod file not found at: ${mod.storagePath}');
      }
      final modData = await modFile.readAsBytes();

      // TODO: Read original game file via Shizuku bridge
      // final shizuku = ref.read(shizukuBridgeProvider);
      // final originalData = await shizuku.readGameFile(mod.targetFile!);
      state = state.copyWith(statusMessage: 'Reading original game file...');
      AppLogger.warning(
        'Shizuku bridge not yet integrated — skipping original file read',
        tag: 'ModApply',
      );

      // CRC patching placeholder — requires original file data from Shizuku
      var crcPatched = false;
      // ignore: unused_local_variable
      var finalData = modData.toList();

      // When Shizuku bridge is available, this will do:
      // final patchResult = CrcPatcher.manipulateCrc(
      //   originalData: originalData,
      //   modData: modData,
      // );
      // if (patchResult.success && patchResult.patchedData != null) {
      //   finalData = patchResult.patchedData!;
      //   crcPatched = true;
      // }

      // TODO: Write patched file to game directory via Shizuku
      // await shizuku.writeGameFile(mod.targetFile!, finalData);
      state = state.copyWith(statusMessage: 'Writing to game directory...');
      AppLogger.warning(
        'Shizuku bridge not yet integrated — skipping game file write',
        tag: 'ModApply',
      );

      // Mark mod as applied
      final repo = ref.read(modRepositoryProvider);
      final updatedMod = mod.copyWith(isApplied: true);
      await repo.updateMod(updatedMod);
      ref.invalidate(modLibraryControllerProvider);

      state = const ModApplyState();

      AppLogger.info(
        'Applied mod: ${mod.name} -> ${mod.targetFile}',
        tag: 'ModApply',
      );

      return ModApplyResult(
        success: true,
        modId: mod.id,
        targetFile: mod.targetFile!,
        crcPatched: crcPatched,
      );
    } catch (e, st) {
      AppLogger.error(
        'Failed to apply mod: ${mod.name}',
        tag: 'ModApply',
        error: e,
        stackTrace: st,
      );

      state = ModApplyState(error: e.toString());

      return ModApplyResult(
        success: false,
        modId: mod.id,
        targetFile: mod.targetFile ?? '',
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
      // TODO: Restore via Shizuku bridge
      // final shizuku = ref.read(shizukuBridgeProvider);
      // await shizuku.restoreBackup(mod.targetFile!);
      AppLogger.warning(
        'Shizuku bridge not yet integrated — skipping restore',
        tag: 'ModApply',
      );

      // Mark mod as unapplied
      final repo = ref.read(modRepositoryProvider);
      final updatedMod = mod.copyWith(isApplied: false);
      await repo.updateMod(updatedMod);
      ref.invalidate(modLibraryControllerProvider);

      state = const ModApplyState();

      AppLogger.info('Restored mod: ${mod.name}', tag: 'ModApply');
      return true;
    } catch (e, st) {
      AppLogger.error(
        'Failed to restore mod: ${mod.name}',
        tag: 'ModApply',
        error: e,
        stackTrace: st,
      );

      state = ModApplyState(error: e.toString());
      return false;
    }
  }

  void clearError() {
    if (state.error != null) {
      state = const ModApplyState();
    }
  }
}
