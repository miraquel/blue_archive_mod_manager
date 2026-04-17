import 'package:bamm/features/mods/domain/entities/mod_asset_category.dart';

class ModAssetMetadata {
  final ModAssetCategory category;
  final String? family;
  final String? variant;
  final String? chunkGroupId;
  final int? chunkIndex;
  final DateTime? assetDate;

  const ModAssetMetadata({
    required this.category,
    this.family,
    this.variant,
    this.chunkGroupId,
    this.chunkIndex,
    this.assetDate,
  });
}
