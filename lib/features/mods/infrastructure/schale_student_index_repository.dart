import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:bamm/core/logging/app_logger.dart';
import 'package:bamm/features/mods/domain/entities/student_profile.dart';
import 'package:bamm/features/mods/domain/repositories/student_index_repository.dart';

class SchaleStudentIndexRepository implements StudentIndexRepository {
  static const _cacheKey = 'student_index_profiles_v1';
  static const _cacheFetchedAtKey = 'student_index_profiles_fetched_at_v1';
  static const _cacheLifetime = Duration(days: 7);
  static final Map<String, Uri> _sourceUrls = {
    'en': Uri.parse('https://schaledb.com/data/en/students.json'),
    'tw': Uri.parse('https://schaledb.com/data/tw/students.json'),
    'cn': Uri.parse('https://schaledb.com/data/cn/students.json'),
  };

  final SharedPreferences _prefs;
  final HttpClient _httpClient;

  SchaleStudentIndexRepository(this._prefs, {HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  @override
  Future<List<StudentProfile>> getProfiles({bool forceRefresh = false}) async {
    final cachedProfiles = forceRefresh ? <StudentProfile>[] : _readCached();
    final cacheIsFresh = !_isCacheStale();

    if (cachedProfiles.isNotEmpty && cacheIsFresh) {
      return cachedProfiles;
    }

    try {
      final freshProfiles = await _fetchProfiles();
      if (freshProfiles.isNotEmpty) {
        await _saveCache(freshProfiles);
      }
      return freshProfiles.isNotEmpty ? freshProfiles : cachedProfiles;
    } on SocketException catch (error, stackTrace) {
      AppLogger.warning(
        'Failed to refresh student index due to connectivity issues.',
        tag: 'StudentIndex',
      );
      AppLogger.error(
        'Socket error while fetching student index',
        tag: 'StudentIndex',
        error: error,
        stackTrace: stackTrace,
      );
      return cachedProfiles;
    } on HttpException catch (error, stackTrace) {
      AppLogger.error(
        'HTTP error while fetching student index',
        tag: 'StudentIndex',
        error: error,
        stackTrace: stackTrace,
      );
      return cachedProfiles;
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(
        'Invalid student index payload received from SchaleDB',
        tag: 'StudentIndex',
        error: error,
        stackTrace: stackTrace,
      );
      return cachedProfiles;
    }
  }

  bool _isCacheStale() {
    final fetchedAt = _prefs.getInt(_cacheFetchedAtKey);
    if (fetchedAt == null) {
      return true;
    }

    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(fetchedAt),
    );
    return age > _cacheLifetime;
  }

  List<StudentProfile> _readCached() {
    final cache = _prefs.getString(_cacheKey);
    if (cache == null || cache.isEmpty) {
      return const [];
    }

    final rawList = json.decode(cache) as List<dynamic>;
    return rawList
        .map((entry) => StudentProfile.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> _saveCache(List<StudentProfile> profiles) async {
    final payload = json.encode(
      profiles.map((profile) => profile.toJson()).toList(),
    );
    await _prefs.setString(_cacheKey, payload);
    await _prefs.setInt(
      _cacheFetchedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<List<StudentProfile>> _fetchProfiles() async {
    final enData = await _fetchLocale('en');
    final twData = await _fetchLocale('tw');
    final cnData = await _fetchLocale('cn');

    final profiles = <StudentProfile>[];

    for (final entry in enData.entries) {
      final studentId = entry.key;
      final enStudent = _asStringMap(entry.value);
      final devName = enStudent['DevName'];
      final nameEn = enStudent['Name'];
      if (devName == null ||
          devName.isEmpty ||
          nameEn == null ||
          nameEn.isEmpty) {
        continue;
      }

      final twStudent = _asStringMap(twData[studentId]);
      final cnStudent = _asStringMap(cnData[studentId]);

      profiles.add(
        StudentProfile(
          id: studentId,
          devName: devName,
          nameEn: nameEn,
          nameTw: twStudent['Name'],
          nameCn: cnStudent['Name'],
        ),
      );
    }

    profiles.sort(
      (left, right) => left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      ),
    );

    AppLogger.info(
      'Loaded ${profiles.length} student profiles from SchaleDB',
      tag: 'StudentIndex',
    );

    return profiles;
  }

  Future<Map<String, dynamic>> _fetchLocale(String locale) async {
    final uri = _sourceUrls[locale];
    if (uri == null) {
      throw StateError('Unsupported locale: $locale');
    }

    final request = await _httpClient.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Unexpected status code ${response.statusCode} for $uri',
        uri: uri,
      );
    }

    final payload = await response.transform(utf8.decoder).join();
    return json.decode(payload) as Map<String, dynamic>;
  }

  Map<String, String> _asStringMap(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return const {};
    }

    return value.map(
      (key, nestedValue) =>
          MapEntry(key, nestedValue is String ? nestedValue : ''),
    );
  }
}
