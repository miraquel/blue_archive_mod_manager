import 'package:bamm/features/recovery/domain/entities/manifest_resource.dart';

/// Classification of a single file comparison between manifest and device.
enum FileDiffStatus {
  /// File exists and matches the manifest (size matches).
  ok,

  /// File exists but size differs from the manifest.
  sizeMismatch,

  /// File listed in manifest but missing from device.
  missing,
}

/// A single file-level diff entry.
class FileDiffEntry {
  final ManifestResource manifestEntry;
  final FileDiffStatus status;
  final int? localSize;

  const FileDiffEntry({
    required this.manifestEntry,
    required this.status,
    this.localSize,
  });

  bool get needsRepair =>
      status == FileDiffStatus.missing ||
      status == FileDiffStatus.sizeMismatch;

  @override
  String toString() =>
      'FileDiffEntry(${manifestEntry.resourcePath}, $status)';
}

/// Aggregated diff result comparing a manifest against an installation.
class RepairDiff {
  final List<FileDiffEntry> entries;
  final int totalManifestFiles;
  final DateTime scannedAt;

  const RepairDiff({
    required this.entries,
    required this.totalManifestFiles,
    required this.scannedAt,
  });

  List<FileDiffEntry> get filesNeedingRepair =>
      entries.where((e) => e.needsRepair).toList(growable: false);

  List<FileDiffEntry> get missingFiles =>
      entries
          .where((e) => e.status == FileDiffStatus.missing)
          .toList(growable: false);

  List<FileDiffEntry> get mismatchedFiles =>
      entries
          .where((e) => e.status == FileDiffStatus.sizeMismatch)
          .toList(growable: false);

  List<FileDiffEntry> get okFiles =>
      entries
          .where((e) => e.status == FileDiffStatus.ok)
          .toList(growable: false);

  bool get isClean => filesNeedingRepair.isEmpty;

  int get repairableCount => filesNeedingRepair.length;

  @override
  String toString() =>
      'RepairDiff($totalManifestFiles total, '
      '${missingFiles.length} missing, '
      '${mismatchedFiles.length} mismatched, '
      '${okFiles.length} ok)';
}
