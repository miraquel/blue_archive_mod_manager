import 'package:bamm/core/constants/app_constants.dart';
import 'package:bamm/features/game_data/domain/entities/backup_entry.dart';
import 'package:bamm/features/game_data/domain/entities/game_file.dart';
import 'package:bamm/features/game_data/domain/entities/game_install.dart';

/// Abstract interface for game data operations.
///
/// Handles detection of game installations, privileged file access via Shizuku,
/// and local backup management.
abstract class GameDataRepository {
  // ---------------------------------------------------------------------------
  // Detection
  // ---------------------------------------------------------------------------

  /// Scan for all installed Blue Archive versions on the device.
  Future<List<GameInstall>> detectInstallations();

  /// Check whether a specific [region] is installed.
  Future<bool> isGameInstalled(GameRegion region);

  // ---------------------------------------------------------------------------
  // File operations (via privileged access)
  // ---------------------------------------------------------------------------

  /// List all files in the game data directory for [install].
  Future<List<GameFile>> listGameFiles(GameInstall install);

  /// Read a game file at [fullPath]. Returns `null` if unreadable.
  Future<List<int>?> readGameFile(String fullPath);

  /// Write [data] to a game file at [fullPath].
  Future<bool> writeGameFile(String fullPath, List<int> data);

  // ---------------------------------------------------------------------------
  // Backup operations
  // ---------------------------------------------------------------------------

  /// Create a local backup of the game file at [gameFilePath].
  Future<BackupEntry> createBackup(String gameFilePath);

  /// Restore a previously created backup to its original location.
  Future<bool> restoreBackup(BackupEntry entry);

  /// List all stored backups.
  Future<List<BackupEntry>> listBackups();

  /// Delete a backup from local storage.
  Future<void> deleteBackup(BackupEntry entry);
}
