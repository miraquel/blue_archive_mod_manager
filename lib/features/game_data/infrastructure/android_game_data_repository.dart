import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bamm/core/constants/app_constants.dart';
import 'package:bamm/core/errors/app_exceptions.dart';
import 'package:bamm/features/game_data/domain/entities/backup_entry.dart';
import 'package:bamm/features/game_data/domain/entities/game_file.dart';
import 'package:bamm/features/game_data/domain/entities/game_install.dart';
import 'package:bamm/features/game_data/domain/repositories/game_data_repository.dart';
import 'package:bamm/features/shizuku/domain/shizuku_bridge.dart';

/// Key used to persist backup metadata in [SharedPreferences].
const _backupsPrefsKey = 'game_data_backups';

/// [GameDataRepository] backed by Shizuku privileged file access.
///
/// Game file operations are delegated to [ShizukuBridge], while backup files
/// are stored in the app's local documents directory.
class AndroidGameDataRepository implements GameDataRepository {
  AndroidGameDataRepository(this._bridge);

  final ShizukuBridge _bridge;

  // ---------------------------------------------------------------------------
  // Detection
  // ---------------------------------------------------------------------------

  @override
  Future<List<GameInstall>> detectInstallations() async {
    final installs = <GameInstall>[];

    for (final region in GameRegion.values) {
      final isInstalled =
          await _bridge.isPackageInstalled(region.packageId);
      if (isInstalled) {
        final basePath =
            '/storage/emulated/0/Android/data/${region.packageId}/'
            '${GamePaths.gameDataRelative}';
        final isAccessible = await _bridge.fileExists(basePath);

        installs.add(GameInstall(
          region: region,
          packageName: region.packageId,
          gameDataPath: basePath,
          isAccessible: isAccessible,
        ));
      }
    }

    return installs;
  }

  @override
  Future<bool> isGameInstalled(GameRegion region) async {
    return _bridge.isPackageInstalled(region.packageId);
  }

  // ---------------------------------------------------------------------------
  // File operations (privileged)
  // ---------------------------------------------------------------------------

  @override
  Future<List<GameFile>> listGameFiles(GameInstall install) async {
    final fileNames = await _bridge.listFiles(install.gameDataPath);
    final backups = await listBackups();
    final backedUpPaths =
        backups.map((b) => b.originalPath).toSet();

    final files = <GameFile>[];
    for (final name in fileNames) {
      final fullPath = p.posix.join(install.gameDataPath, name);
      final isDir = await _bridge.isDirectory(fullPath);
      final size = isDir ? 0 : await _bridge.getFileSize(fullPath);

      files.add(GameFile(
        name: name,
        fullPath: fullPath,
        sizeBytes: size,
        isDirectory: isDir,
        hasBackup: backedUpPaths.contains(fullPath),
      ));
    }

    return files;
  }

  @override
  Future<List<int>?> readGameFile(String fullPath) async {
    return _bridge.readFile(fullPath);
  }

  @override
  Future<bool> writeGameFile(String fullPath, List<int> data) async {
    return _bridge.writeFile(fullPath, data);
  }

  // ---------------------------------------------------------------------------
  // Backup operations (local storage)
  // ---------------------------------------------------------------------------

  @override
  Future<BackupEntry> createBackup(String gameFilePath) async {
    final data = await _bridge.readFile(gameFilePath);
    if (data == null) {
      throw const BackupException('Could not read game file for backup');
    }

    final backupDir = await _backupDirectory();
    final fileName = p.posix.basename(gameFilePath);
    final timestamp = DateTime.now();
    final safeName =
        '${timestamp.millisecondsSinceEpoch}_$fileName';
    final backupPath = p.join(backupDir.path, safeName);

    await File(backupPath).writeAsBytes(data);

    final entry = BackupEntry(
      originalPath: gameFilePath,
      backupPath: backupPath,
      fileName: fileName,
      createdAt: timestamp,
      sizeBytes: data.length,
    );

    await _saveBackupMetadata(entry);
    return entry;
  }

  @override
  Future<bool> restoreBackup(BackupEntry entry) async {
    final backupFile = File(entry.backupPath);
    if (!await backupFile.exists()) {
      throw const BackupException('Backup file no longer exists');
    }

    final data = await backupFile.readAsBytes();
    return _bridge.writeFile(entry.originalPath, data);
  }

  @override
  Future<List<BackupEntry>> listBackups() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_backupsPrefsKey);
    if (raw == null || raw.isEmpty) return [];

    return raw
        .map((json) =>
            BackupEntry.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> deleteBackup(BackupEntry entry) async {
    final backupFile = File(entry.backupPath);
    if (await backupFile.exists()) {
      await backupFile.delete();
    }

    await _removeBackupMetadata(entry);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<Directory> _backupDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _saveBackupMetadata(BackupEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_backupsPrefsKey) ?? [];
    existing.add(jsonEncode(entry.toJson()));
    await prefs.setStringList(_backupsPrefsKey, existing);
  }

  Future<void> _removeBackupMetadata(BackupEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_backupsPrefsKey) ?? [];
    existing.removeWhere((json) {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded['backupPath'] == entry.backupPath;
    });
    await prefs.setStringList(_backupsPrefsKey, existing);
  }
}
