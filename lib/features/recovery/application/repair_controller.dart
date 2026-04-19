import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bamm/core/constants/app_constants.dart';
import 'package:bamm/core/errors/app_exceptions.dart';
import 'package:bamm/core/logging/app_logger.dart';
import 'package:bamm/features/game_data/application/providers.dart';
import 'package:bamm/features/recovery/application/providers.dart';
import 'package:bamm/features/recovery/domain/entities/repair_diff.dart';
import 'package:bamm/features/recovery/domain/entities/repair_result.dart';
import 'package:bamm/features/recovery/domain/entities/version_info.dart';
import 'package:bamm/features/shizuku/application/providers.dart';

/// State for the recovery / repair workflow.
class RepairState {
  final VersionInfo? versionInfo;
  final RepairDiff? lastDiff;
  final bool isScanning;
  final bool isRepairing;
  final String? statusMessage;
  final String? error;
  final int repairedCount;
  final int repairTotal;

  const RepairState({
    this.versionInfo,
    this.lastDiff,
    this.isScanning = false,
    this.isRepairing = false,
    this.statusMessage,
    this.error,
    this.repairedCount = 0,
    this.repairTotal = 0,
  });

  bool get isBusy => isScanning || isRepairing;

  RepairState copyWith({
    VersionInfo? versionInfo,
    RepairDiff? lastDiff,
    bool? isScanning,
    bool? isRepairing,
    String? statusMessage,
    String? error,
    int? repairedCount,
    int? repairTotal,
  }) {
    return RepairState(
      versionInfo: versionInfo ?? this.versionInfo,
      lastDiff: lastDiff ?? this.lastDiff,
      isScanning: isScanning ?? this.isScanning,
      isRepairing: isRepairing ?? this.isRepairing,
      statusMessage: statusMessage,
      error: error,
      repairedCount: repairedCount ?? this.repairedCount,
      repairTotal: repairTotal ?? this.repairTotal,
    );
  }
}

/// Manages the scan-and-repair workflow.
///
/// Workflow:
/// 1. [scanForIssues] fetches the official manifest and diffs against the device.
/// 2. [repairFromManifest] downloads and replaces only the files that differ.
/// 3. [restoreAllBackups] restores all BAMM backups to their original locations.
class RepairController extends Notifier<RepairState> {
  static const _tag = 'Repair';

  @override
  RepairState build() => const RepairState();

  /// Fetch the latest manifest and compare against the selected game install.
  Future<void> scanForIssues() async {
    if (state.isBusy) return;

    state = state.copyWith(
      isScanning: true,
      statusMessage: 'Fetching latest version info...',
      error: null,
    );

    try {
      final bridge = ref.read(shizukuBridgeProvider);
      if (!await bridge.isServiceBound()) {
        throw const ShizukuNotAvailableException(
          'Connect Shizuku before scanning.',
        );
      }

      final gameDataRepo = ref.read(gameDataRepositoryProvider);
      final installs = await gameDataRepo.detectInstallations();
      final globalInstall = installs
          .where((i) => i.region == GameRegion.global && i.isAccessible)
          .toList(growable: false);
      if (globalInstall.isEmpty) {
        throw const GameNotInstalledException(
          'No accessible Global Android installation found.',
        );
      }

      final apiClient = ref.read(nexonApiClientProvider);
      final versionInfo = await apiClient.getLatestVersion(
        marketGameId: GamePackages.global,
      );

      state = state.copyWith(
        versionInfo: versionInfo,
        statusMessage:
            'Fetching manifest (patch ${versionInfo.patchVersion})...',
      );

      final manifest =
          await apiClient.fetchManifest(versionInfo.resourcePath);

      state = state.copyWith(
        statusMessage: 'Scanning ${manifest.length} files...',
      );

      // Filter to only the Android resources relevant to the game data path.
      final androidResources = manifest
          .where((r) => r.resourcePath.startsWith('Android/'))
          .toList(growable: false);

      final diffEngine = ref.read(repairDiffEngineProvider);
      // The gameDataPath points to .../files/PUB/Resource/GameData/Android
      // but manifest paths start with "Android/...", so use the parent.
      final gameDataRoot = globalInstall.first.gameDataPath;
      final parentPath = gameDataRoot.endsWith('/Android')
          ? gameDataRoot.substring(0, gameDataRoot.length - '/Android'.length)
          : gameDataRoot.replaceAll(RegExp(r'/Android$'), '');

      final diff = await diffEngine.computeDiff(
        bridge: bridge,
        gameDataPath: parentPath,
        manifest: androidResources,
        onProgress: (current, total) {
          state = state.copyWith(
            statusMessage: 'Scanning file $current / $total...',
          );
        },
      );

      state = RepairState(
        versionInfo: versionInfo,
        lastDiff: diff,
        statusMessage: diff.isClean
            ? 'All ${diff.totalManifestFiles} files match the official manifest.'
            : '${diff.repairableCount} file(s) need repair '
                '(${diff.missingFiles.length} missing, '
                '${diff.mismatchedFiles.length} mismatched).',
      );

      AppLogger.info(
        'Scan complete: ${diff.totalManifestFiles} total, '
        '${diff.repairableCount} repairable',
        tag: _tag,
      );
    } catch (e, st) {
      AppLogger.error('Scan failed', tag: _tag, error: e, stackTrace: st);
      state = state.copyWith(
        isScanning: false,
        statusMessage: null,
        error: e.toString(),
      );
    }
  }

  /// Download and write back only the files marked as needing repair.
  Future<RepairResult> repairFromManifest() async {
    final diff = state.lastDiff;
    final version = state.versionInfo;
    if (diff == null || version == null) {
      return const RepairResult(
        attemptedCount: 0,
        successCount: 0,
        errorMessage: 'Run a scan first.',
      );
    }

    if (state.isBusy) {
      return const RepairResult(
        attemptedCount: 0,
        successCount: 0,
        errorMessage: 'A repair operation is already in progress.',
      );
    }

    final toRepair = diff.filesNeedingRepair;
    if (toRepair.isEmpty) {
      return const RepairResult(attemptedCount: 0, successCount: 0);
    }

    state = state.copyWith(
      isRepairing: true,
      statusMessage: 'Repairing ${toRepair.length} file(s)...',
      repairedCount: 0,
      repairTotal: toRepair.length,
      error: null,
    );

    final bridge = ref.read(shizukuBridgeProvider);
    final apiClient = ref.read(nexonApiClientProvider);
    final basePath = version.resourceBasePath;

    final gameDataRepo = ref.read(gameDataRepositoryProvider);
    final installs = await gameDataRepo.detectInstallations();
    final globalInstall = installs
        .where((i) => i.region == GameRegion.global && i.isAccessible)
        .first;
    final gameDataRoot = globalInstall.gameDataPath;
    final parentPath = gameDataRoot.endsWith('/Android')
        ? gameDataRoot.substring(0, gameDataRoot.length - '/Android'.length)
        : gameDataRoot.replaceAll(RegExp(r'/Android$'), '');

    var successCount = 0;
    final failedFiles = <String>[];

    for (var i = 0; i < toRepair.length; i++) {
      final entry = toRepair[i];
      final resource = entry.manifestEntry;

      state = state.copyWith(
        statusMessage:
            'Downloading ${i + 1}/${toRepair.length}: ${resource.fileName}...',
        repairedCount: i,
      );

      try {
        final data = await apiClient.downloadResource(
          basePath: basePath,
          resource: resource,
        );

        final fullPath = '$parentPath/${resource.resourcePath}';
        final success = await bridge.writeFile(fullPath, data);
        if (success) {
          successCount++;
        } else {
          failedFiles.add(resource.resourcePath);
        }
      } catch (e) {
        AppLogger.error(
          'Failed to repair: ${resource.resourcePath}',
          tag: _tag,
          error: e,
        );
        failedFiles.add(resource.resourcePath);
      }
    }

    final result = RepairResult(
      attemptedCount: toRepair.length,
      successCount: successCount,
      failedFiles: failedFiles,
    );

    state = state.copyWith(
      isRepairing: false,
      repairedCount: successCount,
      statusMessage: result.isFullSuccess
          ? 'Repaired all ${result.successCount} file(s) successfully.'
          : 'Repaired ${result.successCount}/${result.attemptedCount}. '
              '${result.failureCount} failed.',
    );

    AppLogger.info('Repair result: $result', tag: _tag);
    return result;
  }

  /// Restore all BAMM backups to their original game file locations.
  Future<RepairResult> restoreAllBackups() async {
    if (state.isBusy) {
      return const RepairResult(
        attemptedCount: 0,
        successCount: 0,
        errorMessage: 'A repair operation is already in progress.',
      );
    }

    state = state.copyWith(
      isRepairing: true,
      statusMessage: 'Loading backups...',
      error: null,
    );

    try {
      final backupController =
          ref.read(backupControllerProvider.notifier);
      final backups =
          ref.read(backupControllerProvider).valueOrNull ?? [];

      if (backups.isEmpty) {
        state = state.copyWith(
          isRepairing: false,
          statusMessage: 'No backups to restore.',
        );
        return const RepairResult(attemptedCount: 0, successCount: 0);
      }

      var successCount = 0;
      final failedFiles = <String>[];

      for (var i = 0; i < backups.length; i++) {
        final backup = backups[i];
        state = state.copyWith(
          statusMessage:
              'Restoring ${i + 1}/${backups.length}: ${backup.fileName}...',
          repairedCount: i,
          repairTotal: backups.length,
        );

        final ok = await backupController.restoreBackup(backup);
        if (ok) {
          successCount++;
        } else {
          failedFiles.add(backup.fileName);
        }
      }

      final result = RepairResult(
        attemptedCount: backups.length,
        successCount: successCount,
        failedFiles: failedFiles,
      );

      state = state.copyWith(
        isRepairing: false,
        repairedCount: successCount,
        statusMessage: result.isFullSuccess
            ? 'Restored all ${result.successCount} backup(s).'
            : 'Restored ${result.successCount}/${result.attemptedCount}. '
                '${result.failureCount} failed.',
      );

      return result;
    } catch (e, st) {
      AppLogger.error(
        'Restore all backups failed',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      state = state.copyWith(
        isRepairing: false,
        error: e.toString(),
      );
      return RepairResult(
        attemptedCount: 0,
        successCount: 0,
        errorMessage: e.toString(),
      );
    }
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }
}
