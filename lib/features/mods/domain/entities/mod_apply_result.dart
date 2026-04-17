class ModApplyResult {
  final bool success;
  final String modId;
  final String targetFile;
  final bool crcPatched;
  final String? errorMessage;

  const ModApplyResult({
    required this.success,
    required this.modId,
    required this.targetFile,
    this.crcPatched = false,
    this.errorMessage,
  });

  @override
  String toString() =>
      'ModApplyResult(success: $success, modId: $modId, '
      'targetFile: $targetFile, crcPatched: $crcPatched)';
}
