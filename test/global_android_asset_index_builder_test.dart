import 'package:flutter_test/flutter_test.dart';

import 'package:bamm/features/mods/domain/services/global_android_asset_index_builder.dart';
import 'package:bamm/features/mods/domain/services/mod_asset_metadata_parser.dart';

void main() {
  group('GlobalAndroidAssetIndexBuilder', () {
    const parser = ModAssetMetadataParser();
    const builder = GlobalAndroidAssetIndexBuilder(parser);

    test('builds exact, family, and chunk-group keys from file paths', () {
      final result = builder.buildFromFilePaths([
        '/storage/emulated/0/Android/data/com.nexon.bluearchive/files/PUB/Resource/GameData/Android/academy-_mxload-2024-11-18_assets_all_3812955000.bundle',
        '/storage/emulated/0/Android/data/com.nexon.bluearchive/files/PUB/Resource/GameData/Android/airi_original_icecream-_mxdependency-2024-11-18_001_assets_all_1730297521.bundle',
        '/storage/emulated/0/Android/data/com.nexon.bluearchive/files/PUB/Resource/GameData/Android/airi_original_icecream-_mxdependency-2024-11-18_002_assets_all_1730297521.bundle',
      ]);

      expect(result.fileCount, 3);
      expect(
        result.index.exactFiles,
        contains('academy-_mxload-2024-11-18_assets_all_3812955000.bundle'),
      );
      expect(result.index.familyKeys, contains('airi_original_icecream'));
      expect(
        result.index.chunkGroupIds,
        contains('airi_original_icecream-_mxdependency-2024-11-18'),
      );
    });

    test('deduplicates repeated file metadata', () {
      final result = builder.buildFromFilePaths([
        '/root/UIS-03_SCENARIO-02_CHARACTER-_mxload-2024-11-18_assets_all_64812345.bundle',
        '/root/uis-03_scenario-02_character-_mxload-2024-11-18_assets_all_64812345.bundle',
      ]);

      expect(result.fileCount, 2);
      expect(result.index.exactFiles.length, 1);
      expect(result.index.familyKeys.length, 1);
    });
  });
}
