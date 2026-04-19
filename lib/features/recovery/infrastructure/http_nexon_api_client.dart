import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:bamm/features/recovery/domain/entities/manifest_resource.dart';
import 'package:bamm/features/recovery/domain/entities/version_info.dart';
import 'package:bamm/features/recovery/domain/services/nexon_api_client.dart';

/// HTTP-based implementation of [NexonApiClient] that talks to Nexon's
/// public patch API.
class HttpNexonApiClient implements NexonApiClient {
  HttpNexonApiClient({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final http.Client _client;

  static const _versionCheckUrl =
      'https://api-pub.nexon.com/patch/v1.1/version-check';

  @override
  Future<VersionInfo> getLatestVersion({
    required String marketGameId,
    String marketCode = 'playstore',
    String fallbackVersion = '1.63.277251',
    String fallbackBuildNumber = '277251',
  }) async {
    final body = jsonEncode({
      'market_game_id': marketGameId,
      'market_code': marketCode,
      'curr_build_version': fallbackVersion,
      'curr_build_number': fallbackBuildNumber,
    });

    final response = await _client.post(
      Uri.parse(_versionCheckUrl),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Nexon version-check failed (${response.statusCode}): '
        '${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return VersionInfo.fromJson(json);
  }

  @override
  Future<List<ManifestResource>> fetchManifest(String manifestUrl) async {
    final response = await _client.get(Uri.parse(manifestUrl));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch manifest (${response.statusCode}): '
        '${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final resources = json['resources'] as List<dynamic>? ?? [];

    return resources
        .cast<Map<String, dynamic>>()
        .map(ManifestResource.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<int>> downloadResource({
    required String basePath,
    required ManifestResource resource,
  }) async {
    final url = '$basePath/${resource.resourcePath}';
    final response = await _client.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download ${resource.resourcePath} '
        '(${response.statusCode})',
      );
    }

    return Uint8List.fromList(response.bodyBytes);
  }
}
