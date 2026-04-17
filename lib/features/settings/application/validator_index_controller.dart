import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bamm/core/constants/app_constants.dart';
import 'package:bamm/core/errors/app_exceptions.dart';
import 'package:bamm/core/logging/app_logger.dart';
import 'package:bamm/features/game_data/application/providers.dart';
import 'package:bamm/features/mods/application/providers.dart';
import 'package:bamm/features/mods/domain/entities/global_android_asset_index.dart';
import 'package:bamm/features/mods/domain/entities/global_android_asset_index_snapshot.dart';
import 'package:bamm/features/mods/domain/entities/mod_asset_metadata.dart';
import 'package:bamm/features/shizuku/application/providers.dart';

class ValidatorIndexState {
  const ValidatorIndexState({
    this.snapshot,
    this.isRebuilding = false,
    this.statusMessage,
    this.error,
  });

  final GlobalAndroidAssetIndexSnapshot? snapshot;
  final bool isRebuilding;
  final String? statusMessage;
  final String? error;

  ValidatorIndexState copyWith({
    GlobalAndroidAssetIndexSnapshot? snapshot,
    bool? isRebuilding,
    String? statusMessage,
    String? error,
  }) {
    return ValidatorIndexState(
      snapshot: snapshot ?? this.snapshot,
      isRebuilding: isRebuilding ?? this.isRebuilding,
      statusMessage: statusMessage,
      error: error,
    );
  }
}

class ValidatorIndexController extends AsyncNotifier<ValidatorIndexState> {
  static const _tag = 'ValidatorIndex';

  @override
  Future<ValidatorIndexState> build() async {
    final snapshot = await ref
        .watch(globalAndroidAssetIndexRepositoryProvider)
        .loadSnapshot();
    return ValidatorIndexState(snapshot: snapshot);
  }

  Future<void> rebuildIndex() async {
    final previous = state.valueOrNull ?? const ValidatorIndexState();
    state = AsyncData(
      previous.copyWith(
        isRebuilding: true,
        statusMessage: 'Scanning Global Android files...',
        error: null,
      ),
    );

    try {
      final shizukuBridge = ref.read(shizukuBridgeProvider);
      if (!await shizukuBridge.isServiceBound()) {
        throw const ShizukuNotAvailableException(
          'Connect Shizuku before rebuilding the validator index.',
        );
      }

      final gameDataRepository = ref.read(gameDataRepositoryProvider);
      final installs = await gameDataRepository.detectInstallations();
      final globalInstalls = installs
          .where((install) {
            return install.region == GameRegion.global && install.isAccessible;
          })
          .toList(growable: false);
      final globalInstall = globalInstalls.isEmpty
          ? null
          : globalInstalls.first;

      if (globalInstall == null) {
        throw StateError(
          'No accessible Global Android installation was found under '
          'Android/data/${GamePackages.global}.',
        );
      }

      final filePaths = await _scanGameFiles(
        rootPath: globalInstall.gameDataPath,
        onProgress: (directory, fileCount) {
          state = AsyncData(
            previous.copyWith(
              snapshot: previous.snapshot,
              isRebuilding: true,
              statusMessage:
                  'Scanning ${_compactPath(directory)} ($fileCount files)...',
              error: null,
            ),
          );
        },
      );

      final buildResult = ref
          .read(globalAndroidAssetIndexBuilderProvider)
          .buildFromFilePaths(filePaths);
      final snapshot = await ref
          .read(globalAndroidAssetIndexRepositoryProvider)
          .saveRebuiltSnapshot(
            index: buildResult.index,
            fileCount: buildResult.fileCount,
            sourcePath: globalInstall.gameDataPath,
          );

      await _revalidateMods(snapshot.index);

      ref.invalidate(globalAndroidAssetIndexSnapshotProvider);
      ref.invalidate(globalAndroidAssetIndexProvider);
      ref.invalidate(modLibraryControllerProvider);

      state = AsyncData(
        ValidatorIndexState(
          snapshot: snapshot,
          isRebuilding: false,
          statusMessage:
              'Rebuilt from ${snapshot.fileCount} files in Global Android.',
        ),
      );
    } catch (e, st) {
      AppLogger.error(
        'Failed to rebuild validator index',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      state = AsyncData(
        previous.copyWith(
          isRebuilding: false,
          statusMessage: null,
          error: e.toString(),
        ),
      );
    }
  }

  Future<List<String>> _scanGameFiles({
    required String rootPath,
    required void Function(String directory, int fileCount) onProgress,
  }) async {
    final bridge = ref.read(shizukuBridgeProvider);
    final directories = Queue<String>()..add(rootPath);
    final filePaths = <String>[];

    while (directories.isNotEmpty) {
      final directory = directories.removeLast();
      final entries = await bridge.listFiles(directory);

      for (final entryPath in entries) {
        if (await bridge.isDirectory(entryPath)) {
          directories.add(entryPath);
          continue;
        }

        filePaths.add(entryPath);
      }

      onProgress(directory, filePaths.length);
    }

    return filePaths;
  }

  Future<void> _revalidateMods(GlobalAndroidAssetIndex assetIndex) async {
    final modRepository = ref.read(modRepositoryProvider);
    final validator = ref.read(modCompatibilityValidatorProvider);
    final mods = await modRepository.getAllMods();

    final updatedMods = mods
        .map((mod) {
          final compatibility = validator.validate(
            fileName: mod.originalFileName,
            assetMetadata: ModAssetMetadata(
              category: mod.assetCategory,
              family: mod.assetFamily,
              variant: mod.assetVariant,
              chunkGroupId: mod.chunkGroupId,
              chunkIndex: mod.chunkIndex,
              assetDate: mod.assetDate,
            ),
            assetIndex: assetIndex,
          );

          return mod.copyWith(
            compatibilityStatus: compatibility.status,
            compatibilityReason: compatibility.reason,
          );
        })
        .toList(growable: false);

    await modRepository.replaceAllMods(updatedMods);
  }

  String _compactPath(String path) {
    final segments = path.split('/');
    if (segments.length <= 4) {
      return path;
    }

    return '.../${segments.skip(segments.length - 4).join('/')}';
  }
}
