import 'package:bamm/features/recovery/domain/entities/manifest_resource.dart';
import 'package:bamm/features/recovery/domain/entities/version_info.dart';

/// Interface for communicating with the Nexon version/patch API.
abstract class NexonApiClient {
  /// Fetch the latest version info for a given market game ID.
  Future<VersionInfo> getLatestVersion({
    required String marketGameId,
    String marketCode = 'playstore',
    String fallbackVersion = '1.63.277251',
    String fallbackBuildNumber = '277251',
  });

  /// Fetch the full resource manifest from [manifestUrl].
  ///
  /// Returns all [ManifestResource] entries listed in the manifest.
  Future<List<ManifestResource>> fetchManifest(String manifestUrl);

  /// Download a single resource file.
  ///
  /// [basePath] is the base URL for downloads (derived from [VersionInfo.resourceBasePath]).
  /// [resource] identifies the file to download.
  Future<List<int>> downloadResource({
    required String basePath,
    required ManifestResource resource,
  });
}
