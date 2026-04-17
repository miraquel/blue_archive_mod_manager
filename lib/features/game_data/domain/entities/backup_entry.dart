/// Represents a backup of a game data file stored locally.
class BackupEntry {
  final String originalPath;
  final String backupPath;
  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;

  const BackupEntry({
    required this.originalPath,
    required this.backupPath,
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
  });

  Map<String, dynamic> toJson() {
    return {
      'originalPath': originalPath,
      'backupPath': backupPath,
      'fileName': fileName,
      'createdAt': createdAt.toIso8601String(),
      'sizeBytes': sizeBytes,
    };
  }

  factory BackupEntry.fromJson(Map<String, dynamic> json) {
    return BackupEntry(
      originalPath: json['originalPath'] as String,
      backupPath: json['backupPath'] as String,
      fileName: json['fileName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      sizeBytes: json['sizeBytes'] as int,
    );
  }

  BackupEntry copyWith({
    String? originalPath,
    String? backupPath,
    String? fileName,
    DateTime? createdAt,
    int? sizeBytes,
  }) {
    return BackupEntry(
      originalPath: originalPath ?? this.originalPath,
      backupPath: backupPath ?? this.backupPath,
      fileName: fileName ?? this.fileName,
      createdAt: createdAt ?? this.createdAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupEntry &&
          runtimeType == other.runtimeType &&
          originalPath == other.originalPath &&
          backupPath == other.backupPath &&
          fileName == other.fileName &&
          createdAt == other.createdAt &&
          sizeBytes == other.sizeBytes;

  @override
  int get hashCode =>
      Object.hash(originalPath, backupPath, fileName, createdAt, sizeBytes);

  @override
  String toString() =>
      'BackupEntry(fileName: $fileName, originalPath: $originalPath, '
      'backupPath: $backupPath, createdAt: $createdAt, sizeBytes: $sizeBytes)';
}
