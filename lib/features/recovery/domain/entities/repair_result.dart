/// Result of a repair operation (either backup-restore or manifest-based).
class RepairResult {
  final int attemptedCount;
  final int successCount;
  final List<String> failedFiles;
  final String? errorMessage;

  const RepairResult({
    required this.attemptedCount,
    required this.successCount,
    this.failedFiles = const [],
    this.errorMessage,
  });

  bool get isFullSuccess =>
      errorMessage == null && failedFiles.isEmpty && successCount > 0;

  bool get isPartialSuccess =>
      successCount > 0 && failedFiles.isNotEmpty;

  int get failureCount => failedFiles.length;

  @override
  String toString() =>
      'RepairResult($successCount/$attemptedCount succeeded, '
      '${failedFiles.length} failed)';
}
