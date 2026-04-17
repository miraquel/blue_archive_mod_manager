import 'package:flutter_test/flutter_test.dart';

import 'package:bamm/features/mods/domain/entities/mod_asset_category.dart';
import 'package:bamm/features/mods/domain/entities/mod_entry.dart';
import 'package:bamm/features/mods/domain/services/mod_asset_metadata_parser.dart';

void main() {
  group('ModAssetMetadataParser', () {
    const parser = ModAssetMetadataParser();

    test('extracts student asset metadata from chunked bundles', () {
      final metadata = parser.parse(
        'airi_original_icecream-_mxdependency-2024-11-18_001_assets_all_1730297521.bundle',
        hasStudentMatch: true,
      );

      expect(metadata.category, ModAssetCategory.character);
      expect(metadata.family, 'airi_original_icecream');
      expect(metadata.variant, 'original');
      expect(metadata.chunkIndex, 1);
      expect(
        metadata.chunkGroupId,
        'airi_original_icecream-_mxdependency-2024-11-18',
      );
      expect(metadata.assetDate, DateTime(2024, 11, 18));
    });

    test('detects shared skill assets from filename patterns', () {
      final metadata = parser.parse(
        'assets-_mx-3dobject-common_skill_healbomb_weapon-_mxdependency-2024-11-18_000_assets_all_695917847.bundle',
        hasStudentMatch: false,
      );

      expect(metadata.category, ModAssetCategory.skill);
      expect(
        metadata.family,
        'assets-_mx-3dobject-common_skill_healbomb_weapon',
      );
      expect(metadata.chunkIndex, 0);
    });

    test('detects ui assets from readable prefixes', () {
      final metadata = parser.parse(
        'uis-03_scenario-02_character-_mxload-2024-11-18_assets_all_64812345.bundle',
        hasStudentMatch: false,
      );

      expect(metadata.category, ModAssetCategory.ui);
      expect(metadata.assetDate, DateTime(2024, 11, 18));
    });
  });

  group('ModEntry asset grouping', () {
    final importedAt = DateTime(2026, 4, 17);

    test('uses student and variant for the primary library group', () {
      final mod = ModEntry(
        id: 'mod-asset-1',
        name: 'Airi Icecream',
        originalFileName:
            'airi_original_icecream-_mxdependency-2024-11-18_001_assets_all_1730297521.bundle',
        storagePath: 'D:\\mods\\airi.bundle',
        importedAt: importedAt,
        sizeBytes: 1234,
        studentName: 'Airi',
        assetCategory: ModAssetCategory.character,
        assetVariant: 'original',
      );

      expect(mod.libraryGroupLabel, 'Airi • Original');
    });

    test('routes unresolved unknown assets into needs matching', () {
      final mod = ModEntry(
        id: 'mod-asset-2',
        name: 'mystery',
        originalFileName: 'mystery_mod.bundle',
        storagePath: 'D:\\mods\\mystery.bundle',
        importedAt: importedAt,
        sizeBytes: 321,
      );

      expect(mod.libraryGroupLabel, 'Needs matching');
      expect(mod.needsAttention, isTrue);
    });
  });
}
