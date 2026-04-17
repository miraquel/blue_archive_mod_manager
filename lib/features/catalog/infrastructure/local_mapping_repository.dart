import 'dart:convert';
import 'dart:io';

import 'package:bamm/features/catalog/domain/entities/asset_mapping.dart';
import 'package:bamm/features/catalog/domain/repositories/mapping_repository.dart';
import 'package:path_provider/path_provider.dart';

/// File-backed implementation of [MappingRepository].
///
/// Stores mappings as a JSON array in the app's documents directory.
class LocalMappingRepository implements MappingRepository {
  static const _fileName = 'mapping.json';

  Future<File> _getMappingFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  @override
  Future<List<AssetMapping>> loadMappings() async {
    final file = await _getMappingFile();
    if (!await file.exists()) {
      return const [];
    }

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(contents);
      if (decoded is! List) {
        throw const FormatException('Mapping JSON must be an array');
      }
      return decoded
          .cast<Map<String, dynamic>>()
          .map(AssetMapping.fromJson)
          .toList();
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Failed to parse mapping file: $e');
    }
  }

  @override
  Future<void> saveMappings(List<AssetMapping> mappings) async {
    final file = await _getMappingFile();
    final json = mappings.map((m) => m.toJson()).toList();
    await file.writeAsString(jsonEncode(json));
  }

  @override
  Future<void> importMappingsFromFile(String filePath) async {
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('Source mapping file not found', filePath);
    }

    final contents = await sourceFile.readAsString();

    // Validate JSON before copying
    final decoded = jsonDecode(contents);
    if (decoded is! List) {
      throw const FormatException(
        'Invalid mapping file: expected a JSON array',
      );
    }

    // Parse each entry to validate structure
    final mappings = decoded
        .cast<Map<String, dynamic>>()
        .map(AssetMapping.fromJson)
        .toList();

    await saveMappings(mappings);
  }

  @override
  Future<bool> hasMappings() async {
    final file = await _getMappingFile();
    if (!await file.exists()) return false;
    final contents = await file.readAsString();
    return contents.trim().isNotEmpty;
  }

  @override
  Future<void> clearMappings() async {
    final file = await _getMappingFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
