/// Game package IDs for supported Blue Archive versions.
class GamePackages {
  GamePackages._();

  static const String global = 'com.nexon.bluearchive';
  static const String jp = 'com.YostarJP.BlueArchive';
}

/// Relative paths inside the game's Android data directory.
class GamePaths {
  GamePaths._();

  static const String gameDataRelative = 'files/PUB/Resource/GameData/Android';
}

/// Supported game regions.
enum GameRegion {
  global('Global', GamePackages.global),
  jp('Japan', GamePackages.jp);

  const GameRegion(this.displayName, this.packageId);

  final String displayName;
  final String packageId;
}
