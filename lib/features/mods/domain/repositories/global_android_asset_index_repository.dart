import 'package:bamm/features/mods/domain/entities/global_android_asset_index.dart';
import 'package:bamm/features/mods/domain/entities/global_android_asset_index_snapshot.dart';

abstract class GlobalAndroidAssetIndexRepository {
  Future<GlobalAndroidAssetIndexSnapshot> loadSnapshot();

  Future<GlobalAndroidAssetIndexSnapshot> saveRebuiltSnapshot({
    required GlobalAndroidAssetIndex index,
    required int fileCount,
    required String sourcePath,
  });
}
