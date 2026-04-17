import 'package:bamm/core/constants/app_constants.dart';

/// Represents a detected Blue Archive installation on the device.
class GameInstall {
  final GameRegion region;
  final String packageName;

  /// Full path to the game data directory for this installation.
  final String gameDataPath;

  /// Whether we can access the game data directory via Shizuku.
  final bool isAccessible;

  const GameInstall({
    required this.region,
    required this.packageName,
    required this.gameDataPath,
    required this.isAccessible,
  });

  GameInstall copyWith({
    GameRegion? region,
    String? packageName,
    String? gameDataPath,
    bool? isAccessible,
  }) {
    return GameInstall(
      region: region ?? this.region,
      packageName: packageName ?? this.packageName,
      gameDataPath: gameDataPath ?? this.gameDataPath,
      isAccessible: isAccessible ?? this.isAccessible,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameInstall &&
          runtimeType == other.runtimeType &&
          region == other.region &&
          packageName == other.packageName &&
          gameDataPath == other.gameDataPath &&
          isAccessible == other.isAccessible;

  @override
  int get hashCode =>
      Object.hash(region, packageName, gameDataPath, isAccessible);

  @override
  String toString() =>
      'GameInstall(region: $region, packageName: $packageName, '
      'gameDataPath: $gameDataPath, isAccessible: $isAccessible)';
}
