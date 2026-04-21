import 'package:bamm/features/mods/domain/entities/student_profile.dart';

class ModStudentMatcher {
  const ModStudentMatcher();

  StudentProfile? matchFileName(
    String fileName,
    Iterable<StudentProfile> profiles,
  ) {
    final fileTokens = _tokenize(fileName);
    if (fileTokens.isEmpty) return null;

    return _findBestMatch(
          fileTokens,
          profiles,
          (profile) => [
            if (profile.pathName != null) profile.pathName!,
            profile.devName,
          ],
        ) ??
        _findBestMatch(
          fileTokens,
          profiles,
          (profile) => profile.localizedNames,
        );
  }

  StudentProfile? _findBestMatch(
    Set<String> fileTokens,
    Iterable<StudentProfile> profiles,
    Iterable<String> Function(StudentProfile profile) termsForProfile,
  ) {
    StudentProfile? bestMatch;
    var bestMatchLength = 0;

    for (final profile in profiles) {
      for (final rawTerm in termsForProfile(profile)) {
        final termTokens = _tokenize(rawTerm);
        if (termTokens.isEmpty) continue;

        if (!termTokens.every(fileTokens.contains)) continue;

        if (rawTerm.length > bestMatchLength) {
          bestMatch = profile;
          bestMatchLength = rawTerm.length;
        }
      }
    }

    return bestMatch;
  }

  Set<String> _tokenize(String value) {
    return value
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'))
        .where((t) => t.length >= 2)
        .toSet();
  }
}
