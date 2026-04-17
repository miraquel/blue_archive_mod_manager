import 'package:bamm/features/mods/domain/entities/global_android_asset_index.dart';

enum GlobalAndroidAssetIndexSource { bundled, rebuilt }

class GlobalAndroidAssetIndexSnapshot {
  const GlobalAndroidAssetIndexSnapshot({
    required this.index,
    required this.source,
    required this.fileCount,
    this.builtAt,
    this.sourcePath,
  });

  final GlobalAndroidAssetIndex index;
  final GlobalAndroidAssetIndexSource source;
  final int fileCount;
  final DateTime? builtAt;
  final String? sourcePath;

  bool get isBundled => source == GlobalAndroidAssetIndexSource.bundled;

  String get sourceLabel {
    switch (source) {
      case GlobalAndroidAssetIndexSource.bundled:
        return 'Bundled snapshot';
      case GlobalAndroidAssetIndexSource.rebuilt:
        return 'Device rebuild';
    }
  }
}
