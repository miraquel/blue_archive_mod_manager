import 'package:bamm/features/catalog/domain/entities/asset_mapping.dart';

/// Contract for loading, saving, and managing CRC-to-asset-name mappings.
abstract class MappingRepository {
  /// Loads all stored mappings from the local mapping file.
  Future<List<AssetMapping>> loadMappings();

  /// Persists the given mappings to the local mapping file.
  Future<void> saveMappings(List<AssetMapping> mappings);

  /// Imports a Mapping.json from an external [filePath] into app storage.
  Future<void> importMappingsFromFile(String filePath);

  /// Returns `true` if a local mapping file exists and is non-empty.
  Future<bool> hasMappings();

  /// Deletes the local mapping file.
  Future<void> clearMappings();
}
