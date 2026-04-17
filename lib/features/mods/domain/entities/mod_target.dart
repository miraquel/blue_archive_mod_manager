class ModTarget {
  final String fileName;
  final String fullPath;
  final int sizeBytes;
  final bool hasBackup;

  const ModTarget({
    required this.fileName,
    required this.fullPath,
    required this.sizeBytes,
    this.hasBackup = false,
  });

  @override
  String toString() => 'ModTarget(fileName: $fileName, hasBackup: $hasBackup)';
}
