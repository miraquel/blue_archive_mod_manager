import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:bamm/core/logging/app_logger.dart';
import 'package:bamm/features/mods/application/providers.dart';
import 'package:bamm/features/mods/domain/entities/mod_entry.dart';

class ModImportState {
  final bool isImporting;
  final String? currentFile;
  final double? progress;
  final String? error;

  const ModImportState({
    this.isImporting = false,
    this.currentFile,
    this.progress,
    this.error,
  });

  ModImportState copyWith({
    bool? isImporting,
    String? currentFile,
    double? progress,
    String? error,
  }) {
    return ModImportState(
      isImporting: isImporting ?? this.isImporting,
      currentFile: currentFile ?? this.currentFile,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
}

class ModImportController extends Notifier<ModImportState> {
  static const _uuid = Uuid();

  @override
  ModImportState build() => const ModImportState();

  Future<void> importFromFilePicker() async {
    if (state.isImporting) return;

    state = const ModImportState(isImporting: true);

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) {
        state = const ModImportState();
        return;
      }

      final repo = ref.read(modRepositoryProvider);
      final stagingStore = ref.read(modStagingStoreProvider);
      final totalFiles = result.files.length;

      for (var i = 0; i < totalFiles; i++) {
        final file = result.files[i];
        if (file.path == null) continue;

        final fileName = file.name;
        state = state.copyWith(
          currentFile: fileName,
          progress: (i + 1) / totalFiles,
        );

        AppLogger.info('Importing mod file: $fileName', tag: 'ModImport');

        final modId = _uuid.v4();
        final storagePath = await stagingStore.importToStorage(
          file.path!,
          modId,
        );

        final fileSize = await File(file.path!).length();
        final displayName = p.basenameWithoutExtension(fileName);

        final modEntry = ModEntry(
          id: modId,
          name: displayName,
          originalFileName: fileName,
          storagePath: storagePath,
          importedAt: DateTime.now(),
          sizeBytes: fileSize,
        );

        await repo.saveMod(modEntry);
        AppLogger.info('Imported mod: $displayName ($modId)', tag: 'ModImport');
      }

      // Refresh the library
      ref.invalidate(modLibraryControllerProvider);

      state = const ModImportState();
    } catch (e, st) {
      AppLogger.error(
        'Failed to import mods',
        tag: 'ModImport',
        error: e,
        stackTrace: st,
      );
      state = ModImportState(error: e.toString());
    }
  }

  void clearError() {
    if (state.error != null) {
      state = const ModImportState();
    }
  }
}
