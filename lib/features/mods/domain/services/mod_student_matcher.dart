import 'package:bamm/features/mods/domain/entities/student_profile.dart';

class ModStudentMatcher {
  const ModStudentMatcher();

  StudentProfile? matchFileName(
    String fileName,
    Iterable<StudentProfile> profiles,
  ) {
    final normalizedFileName = _normalize(fileName);
    if (normalizedFileName.isEmpty) {
      return null;
    }

    return _findBestMatch(
          normalizedFileName,
          profiles,
          (profile) => [profile.devName],
        ) ??
        _findBestMatch(
          normalizedFileName,
          profiles,
          (profile) => profile.localizedNames,
        );
  }

  StudentProfile? _findBestMatch(
    String normalizedFileName,
    Iterable<StudentProfile> profiles,
    Iterable<String> Function(StudentProfile profile) termsForProfile,
  ) {
    StudentProfile? bestMatch;
    var bestMatchLength = 0;

    for (final profile in profiles) {
      for (final rawTerm in termsForProfile(profile)) {
        final normalizedTerm = _normalize(rawTerm);
        if (normalizedTerm.length < 2) {
          continue;
        }

        if (!normalizedFileName.contains(normalizedTerm)) {
          continue;
        }

        if (normalizedTerm.length > bestMatchLength) {
          bestMatch = profile;
          bestMatchLength = normalizedTerm.length;
        }
      }
    }

    return bestMatch;
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9\u4e00-\u9fff]+'),
      '',
    );
  }
}
