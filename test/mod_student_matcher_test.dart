import 'package:flutter_test/flutter_test.dart';

import 'package:bamm/features/mods/domain/entities/mod_entry.dart';
import 'package:bamm/features/mods/domain/entities/student_profile.dart';
import 'package:bamm/features/mods/domain/services/mod_student_matcher.dart';

void main() {
  group('ModStudentMatcher', () {
    const matcher = ModStudentMatcher();
    const profiles = [
      StudentProfile(
        id: '1001',
        devName: 'Aru',
        nameEn: 'Aru',
        nameTw: '亞瑠',
        nameCn: '阿露',
      ),
      StudentProfile(
        id: '233',
        devName: 'CH0233',
        nameEn: 'Hina',
        nameTw: '日奈',
        nameCn: '日奈',
      ),
    ];

    test('matches by developer name first', () {
      final match = matcher.matchFileName('portrait_CH0233_idle.png', profiles);

      expect(match?.id, '233');
      expect(match?.displayName, 'Hina');
    });

    test('matches by localized name when dev name is absent', () {
      final match = matcher.matchFileName('阿露_lobby_pose.bundle', profiles);

      expect(match?.id, '1001');
      expect(match?.displayName, 'Aru');
    });

    test('returns null for unrelated files', () {
      final match = matcher.matchFileName(
        'shared_effects_001.bundle',
        profiles,
      );

      expect(match, isNull);
    });
  });

  group('ModEntry', () {
    final importedAt = DateTime(2026, 4, 17);

    test('uses the original filename when no manual override exists', () {
      final mod = ModEntry(
        id: 'mod-1',
        name: 'Aru Portrait',
        originalFileName: 'AruPortrait.bundle',
        storagePath: 'D:\\mods\\mod-1.bundle',
        importedAt: importedAt,
        sizeBytes: 2048,
      );

      expect(mod.targetFile, 'AruPortrait.bundle');
      expect(mod.hasManualTargetOverride, isFalse);
    });

    test('can clear a manual target override', () {
      final mod = ModEntry(
        id: 'mod-2',
        name: 'Aru Lobby',
        originalFileName: 'AruLobby.bundle',
        storagePath: 'D:\\mods\\mod-2.bundle',
        importedAt: importedAt,
        sizeBytes: 2048,
        targetFileOverride: 'ManualTarget.bundle',
      );

      final reset = mod.copyWith(targetFileOverride: null);

      expect(reset.targetFile, 'AruLobby.bundle');
      expect(reset.hasManualTargetOverride, isFalse);
    });
  });
}
