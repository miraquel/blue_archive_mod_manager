/// Version metadata returned by the Nexon version-check API.
class VersionInfo {
  final String latestBuildVersion;
  final String latestBuildNumber;
  final int patchVersion;
  final String resourcePath;

  const VersionInfo({
    required this.latestBuildVersion,
    required this.latestBuildNumber,
    required this.patchVersion,
    required this.resourcePath,
  });

  /// Base URL for downloading individual resources.
  ///
  /// The manifest's [resourcePath] points to the manifest JSON itself.
  /// Individual resource downloads are relative to the parent path.
  String get resourceBasePath {
    final lastSlash = resourcePath.lastIndexOf('/');
    return lastSlash < 0 ? resourcePath : resourcePath.substring(0, lastSlash);
  }

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    final patch = json['patch'] as Map<String, dynamic>;
    return VersionInfo(
      latestBuildVersion: json['latest_build_version'] as String,
      latestBuildNumber: json['latest_build_number'] as String,
      patchVersion: patch['patch_version'] as int,
      resourcePath: patch['resource_path'] as String,
    );
  }

  @override
  String toString() =>
      'VersionInfo(v$latestBuildVersion, patch: $patchVersion)';
}
