import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bamm/features/mods/domain/entities/global_android_asset_index.dart';
import 'package:bamm/features/mods/domain/entities/global_android_asset_index_snapshot.dart';
import 'package:bamm/features/mods/domain/repositories/global_android_asset_index_repository.dart';
import 'package:bamm/features/mods/infrastructure/bundled_global_android_asset_index_loader.dart';

class LocalGlobalAndroidAssetIndexRepository
    implements GlobalAndroidAssetIndexRepository {
  LocalGlobalAndroidAssetIndexRepository(this._prefs, this._bundledLoader);

  static const _overrideFileName = 'global_android_asset_index_override.json';
  static const _rebuiltAtKey = 'global_android_asset_index_rebuilt_at';
  static const _fileCountKey = 'global_android_asset_index_file_count';
  static const _sourcePathKey = 'global_android_asset_index_source_path';

  final SharedPreferences _prefs;
  final BundledGlobalAndroidAssetIndexLoader _bundledLoader;

  @override
  Future<GlobalAndroidAssetIndexSnapshot> loadSnapshot() async {
    final overrideFile = await _overrideFile();
    if (await overrideFile.exists()) {
      try {
        final rawJson = await overrideFile.readAsString();
        final decoded = json.decode(rawJson) as Map<String, dynamic>;
        final index = GlobalAndroidAssetIndex.fromJson(decoded);
        final builtAtRaw = _prefs.getString(_rebuiltAtKey);
        final builtAt = builtAtRaw == null
            ? null
            : DateTime.tryParse(builtAtRaw);
        final fileCount =
            _prefs.getInt(_fileCountKey) ?? index.exactFiles.length;

        return GlobalAndroidAssetIndexSnapshot(
          index: index,
          source: GlobalAndroidAssetIndexSource.rebuilt,
          fileCount: fileCount,
          builtAt: builtAt,
          sourcePath: _prefs.getString(_sourcePathKey),
        );
      } catch (_) {
        await overrideFile.delete();
      }
    }

    final bundled = await _bundledLoader.load();
    return GlobalAndroidAssetIndexSnapshot(
      index: bundled,
      source: GlobalAndroidAssetIndexSource.bundled,
      fileCount: bundled.exactFiles.length,
    );
  }

  @override
  Future<GlobalAndroidAssetIndexSnapshot> saveRebuiltSnapshot({
    required GlobalAndroidAssetIndex index,
    required int fileCount,
    required String sourcePath,
  }) async {
    final overrideFile = await _overrideFile();
    await overrideFile.parent.create(recursive: true);
    await overrideFile.writeAsString(json.encode(index.toJson()));

    final builtAt = DateTime.now();
    await _prefs.setString(_rebuiltAtKey, builtAt.toIso8601String());
    await _prefs.setInt(_fileCountKey, fileCount);
    await _prefs.setString(_sourcePathKey, sourcePath);

    return GlobalAndroidAssetIndexSnapshot(
      index: index,
      source: GlobalAndroidAssetIndexSource.rebuilt,
      fileCount: fileCount,
      builtAt: builtAt,
      sourcePath: sourcePath,
    );
  }

  Future<File> _overrideFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File(p.join(docsDir.path, _overrideFileName));
  }
}
