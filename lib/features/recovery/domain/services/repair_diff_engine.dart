import 'package:bamm/core/logging/app_logger.dart';
import 'package:bamm/features/recovery/domain/entities/manifest_resource.dart';
import 'package:bamm/features/recovery/domain/entities/repair_diff.dart';
import 'package:bamm/features/shizuku/domain/shizuku_bridge.dart';

class _LocalFileRecord {
  const _LocalFileRecord({required this.fullPath, required this.size});

  final String fullPath;
  final int size;
}

/// Compares the official manifest against installed game files to produce
/// a [RepairDiff] identifying missing or mismatched files.
class RepairDiffEngine {
  const RepairDiffEngine();

  static const _tag = 'RepairDiffEngine';

  /// Scan [gameDataPath] via [bridge] and compare against [manifest].
  ///
  /// Strategy:
  /// 1. Pre-scan local files (fast, batched) → keyed by path relative to
  ///    [gameDataPath].
  /// 2. Iterate every manifest entry using [ManifestResource.gameDataRelativePath]
  ///    as the authoritative expected device path.
  /// 3. For entries not found in the pre-scan, fall back to a direct
  ///    [ShizukuBridge.fileExists] call so that silent listing failures (e.g.
  ///    Android directory-listing restrictions) do not produce false positives.
  Future<RepairDiff> computeDiff({
    required ShizukuBridge bridge,
    required String gameDataPath,
    required List<ManifestResource> manifest,
    // ignored — kept for API compatibility; detection no longer relies on it
    Iterable<String> trackedPaths = const [],
    void Function(int current, int total)? onProgress,
  }) async {
    // Build manifest index keyed by gameDataRelativePath (case-insensitive).
    // Only index GameData/ entries — Preload/ paths are CDN-only resources that
    // the game repacks locally under different names and have no 1:1 mapping.
    final manifestByRelPath = <String, ManifestResource>{};
    final gameDataEntries = manifest.where((r) => r.resourcePath.startsWith('GameData/')).toList();
    // Show sub-prefix breakdown for diagnostics.
    final subPrefixes = <String, int>{};
    for (final r in gameDataEntries) {
      final rest = r.resourcePath.substring('GameData/'.length);
      final slash = rest.indexOf('/');
      final sub = slash > 0 ? rest.substring(0, slash) : rest;
      subPrefixes[sub] = (subPrefixes[sub] ?? 0) + 1;
    }
    print('[DIAG] GameData sub-prefixes: $subPrefixes');
    for (final resource in gameDataEntries) {
      manifestByRelPath[resource.gameDataRelativePath.toLowerCase()] = resource;
    }

    // Pre-scan local files for fast size lookup.
    final localFiles = await _scanLocalFiles(
      bridge: bridge,
      rootPath: gameDataPath,
    );
    AppLogger.info(
      'Pre-scan found ${localFiles.length} files under $gameDataPath',
      tag: _tag,
    );

    final pathPrefix = '$gameDataPath/';
    final localByRelPath = <String, _LocalFileRecord>{};
    for (final f in localFiles) {
      if (f.fullPath.startsWith(pathPrefix)) {
        final relPath = f.fullPath.substring(pathPrefix.length).toLowerCase();
        localByRelPath[relPath] = f;
      }
    }

    final entries = <FileDiffEntry>[];
    final manifestList =
        manifestByRelPath.entries.toList(growable: false);

    for (var i = 0; i < manifestList.length; i++) {
      onProgress?.call(i + 1, manifestList.length);

      final resource = manifestList[i].value;
      final relPath = resource.gameDataRelativePath.toLowerCase();
      final expectedPath = '$gameDataPath/${resource.gameDataRelativePath}';

      final localFile = localByRelPath[relPath];

      if (localFile == null) {
        // Not in pre-scan. Verify directly — the scan may have failed silently
        // (listing restricted) while individual path access still works.
        final exists = await bridge.fileExists(expectedPath);
        if (!exists) {
          entries.add(FileDiffEntry(
            manifestEntry: resource,
            status: FileDiffStatus.missing,
            localPath: expectedPath,
          ));
          continue;
        }

        // File exists but the recursive scan missed it; check it individually.
        final size = await bridge.getFileSize(expectedPath);
        await _checkFileSize(
          bridge: bridge,
          resource: resource,
          localPath: expectedPath,
          localSize: size,
          entries: entries,
        );
        continue;
      }

      await _checkFileSize(
        bridge: bridge,
        resource: resource,
        localPath: localFile.fullPath,
        localSize: localFile.size,
        entries: entries,
      );
    }

    final missing = entries.where((e) => e.status == FileDiffStatus.missing).toList();
    final mismatch = entries.where((e) => e.status != FileDiffStatus.missing && e.status != FileDiffStatus.ok).toList();
    print('[DIAG] sample missing paths: ${missing.take(3).map((e) => e.manifestEntry.resourcePath).toList()}');
    print('[DIAG] sample mismatch paths: ${mismatch.take(3).map((e) => e.manifestEntry.resourcePath).toList()}');
    print('[DIAG] sample local keys: ${localByRelPath.keys.take(5).toList()}');

    return RepairDiff(
      entries: entries,
      totalManifestFiles: manifestByRelPath.length,
      scannedAt: DateTime.now(),
    );
  }

  Future<void> _checkFileSize({
    required ShizukuBridge bridge,
    required ManifestResource resource,
    required String localPath,
    required int localSize,
    required List<FileDiffEntry> entries,
  }) async {
    if (localSize != resource.resourceSize) {
      entries.add(FileDiffEntry(
        manifestEntry: resource,
        status: FileDiffStatus.sizeMismatch,
        localSize: localSize,
        localPath: localPath,
      ));
      return;
    }

    if (resource.resourceHash.isEmpty) {
      entries.add(FileDiffEntry(
        manifestEntry: resource,
        status: FileDiffStatus.ok,
        localSize: localSize,
        localPath: localPath,
      ));
      return;
    }

    final localHash = await bridge.getFileMd5(localPath);
    if (localHash == null ||
        localHash != resource.resourceHash.toLowerCase()) {
      entries.add(FileDiffEntry(
        manifestEntry: resource,
        status: FileDiffStatus.hashMismatch,
        localSize: localSize,
        localPath: localPath,
      ));
      return;
    }

    entries.add(FileDiffEntry(
      manifestEntry: resource,
      status: FileDiffStatus.ok,
      localSize: localSize,
      localPath: localPath,
    ));
  }

  Future<List<_LocalFileRecord>> _scanLocalFiles({
    required ShizukuBridge bridge,
    required String rootPath,
  }) async {
    const pageSize = 256;
    final localFiles = <_LocalFileRecord>[];
    final directories = <String>[rootPath];
    final seenDirectories = <String>{rootPath};

    while (directories.isNotEmpty) {
      final directory = directories.removeLast();
      var offset = 0;
      while (true) {
        final entryNames = await bridge.listFilesPage(
          directory,
          offset,
          pageSize,
        );
        if (entryNames.isEmpty) break;

        for (final entryName in entryNames) {
          final entryPath = '$directory/$entryName';
          if (await bridge.isDirectory(entryPath)) {
            if (seenDirectories.add(entryPath)) {
              directories.add(entryPath);
            }
            continue;
          }

          final size = await bridge.getFileSize(entryPath);
          localFiles.add(_LocalFileRecord(fullPath: entryPath, size: size));
        }

        if (entryNames.length < pageSize) break;
        offset += entryNames.length;
      }
    }

    return localFiles;
  }
}
