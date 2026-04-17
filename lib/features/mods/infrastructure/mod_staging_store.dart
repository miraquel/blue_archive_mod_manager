import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:bamm/core/logging/app_logger.dart';

class ModStagingStore {
  static const _stagingDirName = 'mod_staging';
  static const _storageDirName = 'mod_storage';

  Future<String> getStagingDir() async {
    final cacheDir = await getTemporaryDirectory();
    final stagingDir = Directory(p.join(cacheDir.path, _stagingDirName));
    if (!await stagingDir.exists()) {
      await stagingDir.create(recursive: true);
    }
    return stagingDir.path;
  }

  Future<String> getModStorageDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final storageDir = Directory(p.join(appDir.path, _storageDirName));
    if (!await storageDir.exists()) {
      await storageDir.create(recursive: true);
    }
    return storageDir.path;
  }

  Future<String> stageModFile(String sourcePath, String fileName) async {
    final stagingDir = await getStagingDir();
    final destPath = p.join(stagingDir, fileName);
    await File(sourcePath).copy(destPath);
    AppLogger.debug('Staged mod file: $fileName', tag: 'ModStagingStore');
    return destPath;
  }

  Future<String> importToStorage(String sourcePath, String modId) async {
    final storageDir = await getModStorageDir();
    final extension = p.extension(sourcePath);
    final destPath = p.join(storageDir, '$modId$extension');
    await File(sourcePath).copy(destPath);
    AppLogger.info('Imported mod to storage: $modId', tag: 'ModStagingStore');
    return destPath;
  }

  Future<void> deleteFromStorage(String storagePath) async {
    final file = File(storagePath);
    if (await file.exists()) {
      await file.delete();
      AppLogger.info(
        'Deleted mod from storage: $storagePath',
        tag: 'ModStagingStore',
      );
    }
  }

  Future<void> clearStaging() async {
    final stagingDir = Directory(await getStagingDir());
    if (await stagingDir.exists()) {
      await stagingDir.delete(recursive: true);
      await stagingDir.create(recursive: true);
      AppLogger.debug('Cleared staging directory', tag: 'ModStagingStore');
    }
  }
}
