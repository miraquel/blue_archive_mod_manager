import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bamm/core/logging/app_logger.dart';
import 'package:bamm/features/mods/application/providers.dart';
import 'package:bamm/features/mods/domain/entities/mod_entry.dart';

class ModLibraryController extends AsyncNotifier<List<ModEntry>> {
  @override
  Future<List<ModEntry>> build() async {
    final repo = ref.watch(modRepositoryProvider);
    return repo.getAllMods();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(modRepositoryProvider);
      return repo.getAllMods();
    });
  }

  Future<void> deleteMod(String id) async {
    try {
      final repo = ref.read(modRepositoryProvider);
      final stagingStore = ref.read(modStagingStoreProvider);

      final mod = await repo.getModById(id);
      if (mod != null) {
        await stagingStore.deleteFromStorage(mod.storagePath);
      }

      await repo.deleteMod(id);
      AppLogger.info('Deleted mod: $id', tag: 'ModLibrary');
      await refresh();
    } catch (e, st) {
      AppLogger.error('Failed to delete mod: $id', tag: 'ModLibrary', error: e, stackTrace: st);
      state = AsyncError(e, st);
    }
  }

  Future<void> updateModTarget(String modId, String targetFile) async {
    try {
      final repo = ref.read(modRepositoryProvider);
      final mod = await repo.getModById(modId);
      if (mod == null) {
        throw StateError('Mod not found: $modId');
      }

      final updated = mod.copyWith(targetFile: targetFile);
      await repo.updateMod(updated);
      AppLogger.info(
        'Updated mod target: $modId -> $targetFile',
        tag: 'ModLibrary',
      );
      await refresh();
    } catch (e, st) {
      AppLogger.error(
        'Failed to update mod target',
        tag: 'ModLibrary',
        error: e,
        stackTrace: st,
      );
      state = AsyncError(e, st);
    }
  }
}
