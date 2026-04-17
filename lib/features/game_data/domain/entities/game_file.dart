/// Represents a file in the game data directory.
class GameFile {
  final String name;
  final String fullPath;
  final int sizeBytes;
  final bool isDirectory;
  final bool hasBackup;

  const GameFile({
    required this.name,
    required this.fullPath,
    required this.sizeBytes,
    this.isDirectory = false,
    this.hasBackup = false,
  });

  GameFile copyWith({
    String? name,
    String? fullPath,
    int? sizeBytes,
    bool? isDirectory,
    bool? hasBackup,
  }) {
    return GameFile(
      name: name ?? this.name,
      fullPath: fullPath ?? this.fullPath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      isDirectory: isDirectory ?? this.isDirectory,
      hasBackup: hasBackup ?? this.hasBackup,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameFile &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          fullPath == other.fullPath &&
          sizeBytes == other.sizeBytes &&
          isDirectory == other.isDirectory &&
          hasBackup == other.hasBackup;

  @override
  int get hashCode =>
      Object.hash(name, fullPath, sizeBytes, isDirectory, hasBackup);

  @override
  String toString() =>
      'GameFile(name: $name, fullPath: $fullPath, sizeBytes: $sizeBytes, '
      'isDirectory: $isDirectory, hasBackup: $hasBackup)';
}
