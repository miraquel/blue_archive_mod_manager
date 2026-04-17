import 'package:path/path.dart' as p;

import 'package:bamm/features/mods/domain/entities/global_android_asset_index.dart';
import 'package:bamm/features/mods/domain/services/mod_asset_metadata_parser.dart';

class GlobalAndroidAssetIndexBuildResult {
  const GlobalAndroidAssetIndexBuildResult({
    required this.index,
    required this.fileCount,
  });

  final GlobalAndroidAssetIndex index;
  final int fileCount;
}

class GlobalAndroidAssetIndexBuilder {
  const GlobalAndroidAssetIndexBuilder(this._assetMetadataParser);

  final ModAssetMetadataParser _assetMetadataParser;

  GlobalAndroidAssetIndexBuildResult buildFromFilePaths(
    Iterable<String> filePaths,
  ) {
    final exactFiles = <String>{};
    final familyKeys = <String>{};
    final chunkGroupIds = <String>{};
    var fileCount = 0;

    for (final filePath in filePaths) {
      final fileName = p.posix.basename(filePath).trim();
      if (fileName.isEmpty) {
        continue;
      }

      fileCount += 1;
      exactFiles.add(fileName.toLowerCase());

      final metadata = _assetMetadataParser.parse(
        fileName,
        hasStudentMatch: false,
      );

      final family = metadata.family?.trim().toLowerCase();
      if (family != null && family.isNotEmpty) {
        familyKeys.add(family);
      }

      final chunkGroupId = metadata.chunkGroupId?.trim().toLowerCase();
      if (chunkGroupId != null && chunkGroupId.isNotEmpty) {
        chunkGroupIds.add(chunkGroupId);
      }
    }

    return GlobalAndroidAssetIndexBuildResult(
      index: GlobalAndroidAssetIndex(
        exactFiles: exactFiles,
        familyKeys: familyKeys,
        chunkGroupIds: chunkGroupIds,
      ),
      fileCount: fileCount,
    );
  }
}
