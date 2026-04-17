import 'package:bamm/features/mods/domain/entities/global_android_asset_index.dart';
import 'package:bamm/features/mods/domain/entities/mod_asset_category.dart';
import 'package:bamm/features/mods/domain/entities/mod_asset_metadata.dart';
import 'package:bamm/features/mods/domain/entities/mod_compatibility.dart';

class ModCompatibilityValidator {
  const ModCompatibilityValidator();

  ModCompatibilityAssessment validate({
    required String fileName,
    required ModAssetMetadata assetMetadata,
    required GlobalAndroidAssetIndex assetIndex,
  }) {
    final normalizedFileName = fileName.toLowerCase();
    if (assetIndex.exactFiles.contains(normalizedFileName)) {
      return const ModCompatibilityAssessment(
        status: ModCompatibilityStatus.compatible,
        reason: 'Exact filename found in the Global Android asset index.',
      );
    }

    final chunkGroupId = assetMetadata.chunkGroupId?.toLowerCase();
    if (chunkGroupId != null &&
        assetIndex.chunkGroupIds.contains(chunkGroupId)) {
      return const ModCompatibilityAssessment(
        status: ModCompatibilityStatus.compatible,
        reason: 'Bundle group found in the Global Android asset index.',
      );
    }

    final family = assetMetadata.family?.toLowerCase();
    if (family != null && assetIndex.familyKeys.contains(family)) {
      return const ModCompatibilityAssessment(
        status: ModCompatibilityStatus.compatible,
        reason: 'Asset family found in the Global Android asset index.',
      );
    }

    if (assetMetadata.category != ModAssetCategory.unknown) {
      return ModCompatibilityAssessment(
        status: ModCompatibilityStatus.needsReview,
        reason:
            'Recognized ${assetMetadata.category.label.toLowerCase()} asset pattern, but no exact Global Android match was found.',
      );
    }

    return const ModCompatibilityAssessment(
      status: ModCompatibilityStatus.unsupported,
      reason: 'No matching Global Android asset family was found.',
    );
  }
}
