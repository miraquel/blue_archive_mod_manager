class ModEntry {
  final String id;
  final String name;
  final String originalFileName;
  final String storagePath;
  final DateTime importedAt;
  final int sizeBytes;
  final String? targetFile;
  final bool isApplied;
  final String? description;

  const ModEntry({
    required this.id,
    required this.name,
    required this.originalFileName,
    required this.storagePath,
    required this.importedAt,
    required this.sizeBytes,
    this.targetFile,
    this.isApplied = false,
    this.description,
  });

  ModEntry copyWith({
    String? id,
    String? name,
    String? originalFileName,
    String? storagePath,
    DateTime? importedAt,
    int? sizeBytes,
    String? targetFile,
    bool? isApplied,
    String? description,
  }) {
    return ModEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      originalFileName: originalFileName ?? this.originalFileName,
      storagePath: storagePath ?? this.storagePath,
      importedAt: importedAt ?? this.importedAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      targetFile: targetFile ?? this.targetFile,
      isApplied: isApplied ?? this.isApplied,
      description: description ?? this.description,
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
      'targetFile': targetFile,
      'isApplied': isApplied,
      'description': description,
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
      targetFile: json['targetFile'] as String?,
      isApplied: json['isApplied'] as bool? ?? false,
      description: json['description'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModEntry && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ModEntry(id: $id, name: $name, applied: $isApplied)';
}
