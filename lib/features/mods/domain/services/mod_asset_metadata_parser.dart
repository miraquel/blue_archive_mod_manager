import 'package:bamm/features/mods/domain/entities/mod_asset_category.dart';
import 'package:bamm/features/mods/domain/entities/mod_asset_metadata.dart';

class ModAssetMetadataParser {
  static final RegExp _familyPattern = RegExp(
    r'^(.+?)-_mx(?:load|dependency)-',
  );
  static final RegExp _datePattern = RegExp(r'(20\d{2}-\d{2}-\d{2})');
  static final RegExp _chunkPattern = RegExp(
    r'_(\d{3})_assets_all_\d+\.bundle$',
    caseSensitive: false,
  );
  static final RegExp _hashSuffixPattern = RegExp(
    r'_assets_all_\d+\.bundle$',
    caseSensitive: false,
  );
  static final RegExp _studentVariantPattern = RegExp(
    r'^([a-z]+)_(original|birthday|ex|idol|casual|insane|event|tails|swimsuit|newyear|christmas|track|camp|hotspring|bunny|maid|dress|armor|sport|sports|icecream)(?:_|$)',
  );

  const ModAssetMetadataParser();

  ModAssetMetadata parse(String fileName, {required bool hasStudentMatch}) {
    final normalizedFileName = fileName.toLowerCase();
    final family = _extractFamily(fileName);
    final assetDate = _extractDate(normalizedFileName);
    final chunkIndex = _extractChunkIndex(normalizedFileName);
    final chunkGroupId = _extractChunkGroupId(normalizedFileName);
    final variant = _extractVariant(normalizedFileName);
    final category = _detectCategory(
      normalizedFileName,
      hasStudentMatch: hasStudentMatch,
    );

    return ModAssetMetadata(
      category: category,
      family: family,
      variant: variant,
      chunkGroupId: chunkGroupId,
      chunkIndex: chunkIndex,
      assetDate: assetDate,
    );
  }

  ModAssetCategory _detectCategory(
    String normalizedFileName, {
    required bool hasStudentMatch,
  }) {
    if (hasStudentMatch ||
        _studentVariantPattern.hasMatch(normalizedFileName)) {
      return ModAssetCategory.character;
    }

    if (normalizedFileName.startsWith('audio-')) {
      return ModAssetCategory.audio;
    }

    if (normalizedFileName.startsWith('ui') ||
        normalizedFileName.startsWith('uis-')) {
      return ModAssetCategory.ui;
    }

    if (normalizedFileName.contains('skill')) {
      return ModAssetCategory.skill;
    }

    if (normalizedFileName.startsWith('effect-') ||
        normalizedFileName.contains('effect') ||
        normalizedFileName.startsWith('fx-')) {
      return ModAssetCategory.effect;
    }

    if (normalizedFileName.startsWith('academy-') ||
        normalizedFileName.startsWith('assets-cafe') ||
        normalizedFileName.startsWith('assets-npcs') ||
        normalizedFileName.startsWith('assets-obstacles') ||
        normalizedFileName.contains('3dobject')) {
      return ModAssetCategory.environment;
    }

    if (normalizedFileName.startsWith('assets-') ||
        normalizedFileName.startsWith('media')) {
      return ModAssetCategory.shared;
    }

    return ModAssetCategory.unknown;
  }

  String? _extractFamily(String fileName) {
    final familyMatch = _familyPattern.firstMatch(fileName);
    if (familyMatch != null) {
      return familyMatch.group(1);
    }

    final chunkless = fileName.replaceAll(_chunkPattern, '');
    final hashless = chunkless.replaceAll(_hashSuffixPattern, '');
    final withoutExtension = hashless.replaceAll('.bundle', '');
    return withoutExtension.isEmpty ? null : withoutExtension;
  }

  String? _extractVariant(String normalizedFileName) {
    final match = _studentVariantPattern.firstMatch(normalizedFileName);
    return match?.group(2);
  }

  int? _extractChunkIndex(String normalizedFileName) {
    final match = _chunkPattern.firstMatch(normalizedFileName);
    if (match == null) {
      return null;
    }

    return int.tryParse(match.group(1)!);
  }

  String? _extractChunkGroupId(String normalizedFileName) {
    if (_chunkPattern.hasMatch(normalizedFileName)) {
      return normalizedFileName.replaceFirst(_chunkPattern, '');
    }

    if (_hashSuffixPattern.hasMatch(normalizedFileName)) {
      return normalizedFileName.replaceFirst(_hashSuffixPattern, '');
    }

    return null;
  }

  DateTime? _extractDate(String normalizedFileName) {
    final match = _datePattern.firstMatch(normalizedFileName);
    if (match == null) {
      return null;
    }

    return DateTime.tryParse(match.group(1)!);
  }
}
