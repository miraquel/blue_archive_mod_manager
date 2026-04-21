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
        pathName: 'aru',
        devName: 'Aru',
        nameEn: 'Aru',
        nameTw: '亞瑠',
        nameCn: '阿露',
      ),
      StudentProfile(
        id: '1002',
        pathName: 'aru_newyear',
        devName: 'Aru_NewYear',
        nameEn: 'Aru',
      ),
      StudentProfile(
        id: '233',
        devName: 'CH0233',
        nameEn: 'Hina',
        nameTw: '日奈',
        nameCn: '日奈',
      ),
    ];

    test('matches by path name first', () {
      final match = matcher.matchFileName(
        'aru_newyear-_mxdependency-2024-11-18_000_assets_all_2578014769.bundle',
        profiles,
      );

      expect(match?.id, '1002');
      expect(match?.pathName, 'aru_newyear');
    });

    test('matches by developer name when no path name', () {
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

  group('ModStudentMatcher regression', () {
    const matcher = ModStudentMatcher();

    // "aris" must not match a Mari file because "aris" only appears as a
    // substring inside the "maris" token sequence (mari_spr → marisspr after
    // old normalization), not as its own token.
    test('does not match Aris when filename belongs to Mari', () {
      const aris = StudentProfile(
        id: '10000',
        pathName: 'aris',
        devName: 'Aris',
        nameEn: 'Aris',
      );
      const mari = StudentProfile(
        id: '10001',
        pathName: 'mari',
        devName: 'Mari',
        nameEn: 'Mari',
      );

      final match = matcher.matchFileName(
        'assets-_mx-spinecharacters-mari_spr-_mxdependency-2024-11-18-002_assets_all_3593738173.bundle',
        [aris, mari],
      );

      expect(match?.id, '10001');
      expect(match?.devName, 'Mari');
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
