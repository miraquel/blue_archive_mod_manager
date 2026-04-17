import 'package:bamm/features/mods/domain/entities/mod_asset_category.dart';
import 'package:bamm/features/mods/domain/entities/mod_compatibility.dart';

class ModEntry {
  static const Object _unset = Object();

  final String id;
  final String name;
  final String originalFileName;
  final String storagePath;
  final DateTime importedAt;
  final int sizeBytes;
  final String? targetFileOverride;
  final bool isApplied;
  final String? description;
  final String? studentId;
  final String? studentDevName;
  final String? studentName;
  final ModAssetCategory assetCategory;
  final String? assetFamily;
  final String? assetVariant;
  final String? chunkGroupId;
  final int? chunkIndex;
  final DateTime? assetDate;
  final ModCompatibilityStatus compatibilityStatus;
  final String? compatibilityReason;

  const ModEntry({
    required this.id,
    required this.name,
    required this.originalFileName,
    required this.storagePath,
    required this.importedAt,
    required this.sizeBytes,
    this.targetFileOverride,
    this.isApplied = false,
    this.description,
    this.studentId,
    this.studentDevName,
    this.studentName,
    this.assetCategory = ModAssetCategory.unknown,
    this.assetFamily,
    this.assetVariant,
    this.chunkGroupId,
    this.chunkIndex,
    this.assetDate,
    this.compatibilityStatus = ModCompatibilityStatus.needsReview,
    this.compatibilityReason,
  });

  String get targetFile {
    final override = targetFileOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return originalFileName;
  }

  bool get hasManualTargetOverride {
    final override = targetFileOverride?.trim();
    return override != null && override.isNotEmpty;
  }

  bool get hasStudentMatch =>
      (studentId?.isNotEmpty ?? false) ||
      (studentDevName?.isNotEmpty ?? false) ||
      (studentName?.isNotEmpty ?? false);

  String get studentGroupLabel {
    final normalizedName = studentName?.trim();
    if (normalizedName != null && normalizedName.isNotEmpty) {
      return normalizedName;
    }
    return 'Needs matching';
  }

  bool get needsAttention =>
      !hasStudentMatch && assetCategory == ModAssetCategory.unknown;

  bool get isChunked => chunkIndex != null;

  bool get isLikelyUnsupported =>
      compatibilityStatus == ModCompatibilityStatus.unsupported;

  String get libraryGroupLabel {
    if (hasStudentMatch) {
      final variantLabel = assetVariantLabel;
      if (variantLabel != null) {
        return '$studentGroupLabel • $variantLabel';
      }
      return studentGroupLabel;
    }

    if (assetCategory != ModAssetCategory.unknown) {
      return assetCategory.label;
    }

    return 'Needs matching';
  }

  String? get assetFamilyLabel {
    final normalizedFamily = assetFamily?.trim();
    if (normalizedFamily == null || normalizedFamily.isEmpty) {
      return null;
    }

    return _toDisplayLabel(normalizedFamily);
  }

  String? get assetVariantLabel {
    final normalizedVariant = assetVariant?.trim();
    if (normalizedVariant == null || normalizedVariant.isEmpty) {
      return null;
    }

    return _toDisplayLabel(normalizedVariant);
  }

  ModEntry copyWith({
    String? id,
    String? name,
    String? originalFileName,
    String? storagePath,
    DateTime? importedAt,
    int? sizeBytes,
    Object? targetFileOverride = _unset,
    bool? isApplied,
    String? description,
    Object? studentId = _unset,
    Object? studentDevName = _unset,
    Object? studentName = _unset,
    ModAssetCategory? assetCategory,
    String? assetFamily,
    String? assetVariant,
    String? chunkGroupId,
    int? chunkIndex,
    DateTime? assetDate,
    ModCompatibilityStatus? compatibilityStatus,
    String? compatibilityReason,
  }) {
    return ModEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      originalFileName: originalFileName ?? this.originalFileName,
      storagePath: storagePath ?? this.storagePath,
      importedAt: importedAt ?? this.importedAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      targetFileOverride: identical(targetFileOverride, _unset)
          ? this.targetFileOverride
          : targetFileOverride as String?,
      isApplied: isApplied ?? this.isApplied,
      description: description ?? this.description,
      studentId: identical(studentId, _unset)
          ? this.studentId
          : studentId as String?,
      studentDevName: identical(studentDevName, _unset)
          ? this.studentDevName
          : studentDevName as String?,
      studentName: identical(studentName, _unset)
          ? this.studentName
          : studentName as String?,
      assetCategory: assetCategory ?? this.assetCategory,
      assetFamily: assetFamily ?? this.assetFamily,
      assetVariant: assetVariant ?? this.assetVariant,
      chunkGroupId: chunkGroupId ?? this.chunkGroupId,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      assetDate: assetDate ?? this.assetDate,
      compatibilityStatus: compatibilityStatus ?? this.compatibilityStatus,
      compatibilityReason: compatibilityReason ?? this.compatibilityReason,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'originalFileName': originalFileName,
      'storagePath': storagePath,
      'importedAt': importedAt.toIso8601String(),
      'sizeBytes': sizeBytes,
      'targetFile': targetFileOverride,
      'targetFileOverride': targetFileOverride,
      'isApplied': isApplied,
      'description': description,
      'studentId': studentId,
      'studentDevName': studentDevName,
      'studentName': studentName,
      'assetCategory': assetCategory.name,
      'assetFamily': assetFamily,
      'assetVariant': assetVariant,
      'chunkGroupId': chunkGroupId,
      'chunkIndex': chunkIndex,
      'assetDate': assetDate?.toIso8601String(),
      'compatibilityStatus': compatibilityStatus.name,
      'compatibilityReason': compatibilityReason,
    };
  }

  factory ModEntry.fromJson(Map<String, dynamic> json) {
    return ModEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      originalFileName: json['originalFileName'] as String,
      storagePath: json['storagePath'] as String,
      importedAt: DateTime.parse(json['importedAt'] as String),
      sizeBytes: json['sizeBytes'] as int,
      targetFileOverride:
          (json['targetFileOverride'] ?? json['targetFile']) as String?,
      isApplied: json['isApplied'] as bool? ?? false,
      description: json['description'] as String?,
      studentId: json['studentId'] as String?,
      studentDevName: json['studentDevName'] as String?,
      studentName: json['studentName'] as String?,
      assetCategory: _assetCategoryFromJson(json['assetCategory'] as String?),
      assetFamily: json['assetFamily'] as String?,
      assetVariant: json['assetVariant'] as String?,
      chunkGroupId: json['chunkGroupId'] as String?,
      chunkIndex: json['chunkIndex'] as int?,
      assetDate: json['assetDate'] != null
          ? DateTime.parse(json['assetDate'] as String)
          : null,
      compatibilityStatus: _compatibilityStatusFromJson(
        json['compatibilityStatus'] as String?,
      ),
      compatibilityReason: json['compatibilityReason'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModEntry && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ModEntry(id: $id, name: $name, targetFile: $targetFile, '
      'student: $studentGroupLabel, applied: $isApplied)';

  static ModAssetCategory _assetCategoryFromJson(String? value) {
    if (value == null) {
      return ModAssetCategory.unknown;
    }

    return ModAssetCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => ModAssetCategory.unknown,
    );
  }

  static ModCompatibilityStatus _compatibilityStatusFromJson(String? value) {
    if (value == null) {
      return ModCompatibilityStatus.needsReview;
    }

    return ModCompatibilityStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ModCompatibilityStatus.needsReview,
    );
  }

  static String _toDisplayLabel(String rawValue) {
    final normalized = rawValue
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) {
      return rawValue;
    }

    return normalized
        .split(' ')
        .map((segment) {
          if (segment.isEmpty) {
            return segment;
          }
          return '${segment[0].toUpperCase()}${segment.substring(1)}';
        })
        .join(' ');
  }
}
