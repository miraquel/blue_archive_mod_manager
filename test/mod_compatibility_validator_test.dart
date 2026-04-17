import 'package:flutter_test/flutter_test.dart';

import 'package:bamm/features/mods/domain/entities/global_android_asset_index.dart';
import 'package:bamm/features/mods/domain/entities/mod_compatibility.dart';
import 'package:bamm/features/mods/domain/services/mod_asset_metadata_parser.dart';
import 'package:bamm/features/mods/domain/services/mod_compatibility_validator.dart';

void main() {
  group('ModCompatibilityValidator', () {
    const parser = ModAssetMetadataParser();
    const validator = ModCompatibilityValidator();
    const assetIndex = GlobalAndroidAssetIndex(
      exactFiles: {'academy-_mxload-2024-11-18_assets_all_3812955000.bundle'},
      familyKeys: {'airi_original_icecream'},
      chunkGroupIds: {'airi_original_icecream-_mxdependency-2024-11-18'},
    );

    test('marks exact filenames as compatible', () {
      final metadata = parser.parse(
        'academy-_mxload-2024-11-18_assets_all_3812955000.bundle',
        hasStudentMatch: false,
      );

      final result = validator.validate(
        fileName: 'academy-_mxload-2024-11-18_assets_all_3812955000.bundle',
        assetMetadata: metadata,
        assetIndex: assetIndex,
      );

      expect(result.status, ModCompatibilityStatus.compatible);
    });

    test('marks matching chunk groups as compatible', () {
      final metadata = parser.parse(
        'airi_original_icecream-_mxdependency-2024-11-18_001_assets_all_1730297521.bundle',
        hasStudentMatch: true,
      );

      final result = validator.validate(
        fileName:
            'airi_original_icecream-_mxdependency-2024-11-18_001_assets_all_1730297521.bundle',
        assetMetadata: metadata,
        assetIndex: assetIndex,
      );

      expect(result.status, ModCompatibilityStatus.compatible);
    });

    test('marks recognized categories without matches as needs review', () {
      final metadata = parser.parse(
        'uis-03_scenario-02_character-_mxload-2024-11-18_assets_all_64812345.bundle',
        hasStudentMatch: false,
      );

      final result = validator.validate(
        fileName:
            'uis-03_scenario-02_character-_mxload-2024-11-18_assets_all_64812345.bundle',
        assetMetadata: metadata,
        assetIndex: assetIndex,
      );

      expect(result.status, ModCompatibilityStatus.needsReview);
    });

    test('marks unknown patterns without matches as unsupported', () {
      final metadata = parser.parse(
        'mystery_bundle_for_pc_only.bundle',
        hasStudentMatch: false,
      );

      final result = validator.validate(
        fileName: 'mystery_bundle_for_pc_only.bundle',
        assetMetadata: metadata,
        assetIndex: assetIndex,
      );

      expect(result.status, ModCompatibilityStatus.unsupported);
    });
  });
}
