import 'package:bamm/features/recovery/domain/entities/manifest_resource.dart';
import 'package:bamm/features/recovery/domain/entities/repair_diff.dart';
import 'package:bamm/features/shizuku/domain/shizuku_bridge.dart';

/// Compares the official manifest against installed game files to produce
/// a [RepairDiff] identifying missing or mismatched files.
class RepairDiffEngine {
  const RepairDiffEngine();

  /// Scan the [gameDataPath] via [bridge] and compare against [manifest].
  ///
  /// Reports progress through [onProgress] with the current file index and total.
  Future<RepairDiff> computeDiff({
    required ShizukuBridge bridge,
    required String gameDataPath,
    required List<ManifestResource> manifest,
    void Function(int current, int total)? onProgress,
  }) async {
    // Build a lookup of local file sizes by relative path.
    // Manifest resource paths are relative (e.g. "Android/foo.bundle").
    // Game data path is the absolute root for the Android asset directory.
    final entries = <FileDiffEntry>[];

    for (var i = 0; i < manifest.length; i++) {
      final resource = manifest[i];
      onProgress?.call(i + 1, manifest.length);

      // Construct full device path from game data root + resource path.
      // The resource_path in the manifest uses forward slashes.
      final fullPath = '$gameDataPath/${resource.resourcePath}';

      final exists = await bridge.fileExists(fullPath);
      if (!exists) {
        entries.add(FileDiffEntry(
          manifestEntry: resource,
          status: FileDiffStatus.missing,
        ));
        continue;
      }

      final localSize = await bridge.getFileSize(fullPath);
      if (localSize != resource.resourceSize) {
        entries.add(FileDiffEntry(
          manifestEntry: resource,
          status: FileDiffStatus.sizeMismatch,
          localSize: localSize,
        ));
      } else {
        entries.add(FileDiffEntry(
          manifestEntry: resource,
          status: FileDiffStatus.ok,
          localSize: localSize,
        ));
      }
    }

    return RepairDiff(
      entries: entries,
      totalManifestFiles: manifest.length,
      scannedAt: DateTime.now(),
    );
  }
}
