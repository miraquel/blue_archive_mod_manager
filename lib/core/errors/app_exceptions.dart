class ShizukuNotAvailableException implements Exception {
  const ShizukuNotAvailableException([this.message = 'Shizuku is not available']);
  final String message;

  @override
  String toString() => 'ShizukuNotAvailableException: $message';
}

class ShizukuPermissionDeniedException implements Exception {
  const ShizukuPermissionDeniedException(
      [this.message = 'Shizuku permission denied']);
  final String message;

  @override
  String toString() => 'ShizukuPermissionDeniedException: $message';
}

class GameNotInstalledException implements Exception {
  const GameNotInstalledException(
      [this.message = 'Game is not installed on this device']);
  final String message;

  @override
  String toString() => 'GameNotInstalledException: $message';
}

class GameDataNotFoundException implements Exception {
  const GameDataNotFoundException(
      [this.message = 'Game data directory not found']);
  final String message;

  @override
  String toString() => 'GameDataNotFoundException: $message';
}

class ModApplyException implements Exception {
  const ModApplyException([this.message = 'Failed to apply mod']);
  final String message;

  @override
  String toString() => 'ModApplyException: $message';
}

class BackupException implements Exception {
  const BackupException([this.message = 'Backup operation failed']);
  final String message;

  @override
  String toString() => 'BackupException: $message';
}

class CrcPatchException implements Exception {
  const CrcPatchException([this.message = 'CRC patch operation failed']);
  final String message;

  @override
  String toString() => 'CrcPatchException: $message';
}

class RepairException implements Exception {
  const RepairException([this.message = 'Repair operation failed']);
  final String message;

  @override
  String toString() => 'RepairException: $message';
}
