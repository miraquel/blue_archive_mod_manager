import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:bamm/features/mods/domain/services/crc_patcher.dart';

void main() {
  // -------------------------------------------------------------------------
  // CRC32 computation
  // -------------------------------------------------------------------------
  group('CRC32 computation', () {
    test('CRC32 of "123456789" is 0xCBF43926', () {
      final data = '123456789'.codeUnits;
      expect(CrcPatcher.computeCrc32(data), 0xCBF43926);
    });

    test('CRC32 of empty data is 0x00000000', () {
      expect(CrcPatcher.computeCrc32([]), 0x00000000);
    });

    test('CRC32 of single zero byte is 0xD202EF8D', () {
      expect(CrcPatcher.computeCrc32([0x00]), 0xD202EF8D);
    });

    test('CRC32 of single 0xFF byte is 0xFF000000', () {
      expect(CrcPatcher.computeCrc32([0xFF]), 0xFF000000);
    });

    test('CRC32 of "Hello, World!" is 0xEC4AC3D0', () {
      final data = 'Hello, World!'.codeUnits;
      expect(CrcPatcher.computeCrc32(data), 0xEC4AC3D0);
    });

    test('CRC32 is deterministic', () {
      final data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      expect(CrcPatcher.computeCrc32(data), CrcPatcher.computeCrc32(data));
    });
  });

  // -------------------------------------------------------------------------
  // CRC patching — matching CRCs
  // -------------------------------------------------------------------------
  group('CRC patching — already matching', () {
    test('identical data needs no correction', () {
      final data = [10, 20, 30, 40, 50];
      final result = CrcPatcher.manipulateCrc(
        originalData: data,
        modData: List<int>.from(data),
      );
      expect(result.success, isTrue);
      expect(result.patchedData, data);
      expect(result.message, contains('already matches'));
    });

    test('both empty needs no correction', () {
      final result = CrcPatcher.manipulateCrc(
        originalData: [],
        modData: [],
      );
      expect(result.success, isTrue);
      expect(result.patchedData, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // CRC patching — different CRCs
  // -------------------------------------------------------------------------
  group('CRC patching — correction', () {
    test('simple correction: small data', () {
      final original = [0x01, 0x02, 0x03];
      final mod = [0xAA, 0xBB, 0xCC, 0xDD];
      final result = CrcPatcher.manipulateCrc(
        originalData: original,
        modData: mod,
      );
      expect(result.success, isTrue);
      expect(result.patchedData, isNotNull);
      expect(result.patchedData!.length, mod.length + 4);
      expect(
        CrcPatcher.computeCrc32(result.patchedData!),
        CrcPatcher.computeCrc32(original),
      );
    });

    test('correction with longer data', () {
      final rng = Random(42);
      final original = List.generate(256, (_) => rng.nextInt(256));
      final mod = List.generate(512, (_) => rng.nextInt(256));
      final result = CrcPatcher.manipulateCrc(
        originalData: original,
        modData: mod,
      );
      expect(result.success, isTrue);
      expect(
        CrcPatcher.computeCrc32(result.patchedData!),
        CrcPatcher.computeCrc32(original),
      );
    });

    test('correction preserves original mod data prefix', () {
      final original = [5, 6, 7];
      final mod = [10, 20, 30, 40];
      final result = CrcPatcher.manipulateCrc(
        originalData: original,
        modData: mod,
      );
      expect(result.success, isTrue);
      expect(result.patchedData!.sublist(0, mod.length), mod);
    });

    test('single byte original vs single byte mod', () {
      final original = [0x42];
      final mod = [0x99];
      final result = CrcPatcher.manipulateCrc(
        originalData: original,
        modData: mod,
      );
      expect(result.success, isTrue);
      expect(
        CrcPatcher.computeCrc32(result.patchedData!),
        CrcPatcher.computeCrc32(original),
      );
    });

    test('mod is empty, original is not', () {
      final original = [1, 2, 3];
      final mod = <int>[];
      final result = CrcPatcher.manipulateCrc(
        originalData: original,
        modData: mod,
      );
      expect(result.success, isTrue);
      expect(result.patchedData!.length, 4);
      expect(
        CrcPatcher.computeCrc32(result.patchedData!),
        CrcPatcher.computeCrc32(original),
      );
    });

    test('original is empty, mod is not', () {
      final original = <int>[];
      final mod = [1, 2, 3];
      final result = CrcPatcher.manipulateCrc(
        originalData: original,
        modData: mod,
      );
      expect(result.success, isTrue);
      expect(
        CrcPatcher.computeCrc32(result.patchedData!),
        CrcPatcher.computeCrc32(original),
      );
    });

    test('large random data', () {
      final rng = Random(123);
      final original = List.generate(10000, (_) => rng.nextInt(256));
      final mod = List.generate(8000, (_) => rng.nextInt(256));
      final result = CrcPatcher.manipulateCrc(
        originalData: original,
        modData: mod,
      );
      expect(result.success, isTrue);
      expect(
        CrcPatcher.computeCrc32(result.patchedData!),
        CrcPatcher.computeCrc32(original),
      );
    });

    test('patching multiple different mods to same original CRC', () {
      final original = 'Blue Archive'.codeUnits;
      final mods = [
        'Mod A'.codeUnits,
        'Mod B with longer data'.codeUnits,
        [0xFF, 0x00, 0xFF, 0x00],
        [42],
      ];
      final targetCrc = CrcPatcher.computeCrc32(original);

      for (final mod in mods) {
        final result = CrcPatcher.manipulateCrc(
          originalData: original,
          modData: List<int>.from(mod),
        );
        expect(result.success, isTrue,
            reason: 'Failed for mod of length ${mod.length}');
        expect(CrcPatcher.computeCrc32(result.patchedData!), targetCrc);
      }
    });
  });

  // -------------------------------------------------------------------------
  // Consistency across many random pairs
  // -------------------------------------------------------------------------
  group('Consistency', () {
    test('patching is consistent across 50 random pairs', () {
      final rng = Random(999);
      for (var i = 0; i < 50; i++) {
        final origLen = rng.nextInt(200) + 1;
        final modLen = rng.nextInt(200) + 1;
        final original = List.generate(origLen, (_) => rng.nextInt(256));
        final mod = List.generate(modLen, (_) => rng.nextInt(256));

        final result = CrcPatcher.manipulateCrc(
          originalData: original,
          modData: mod,
        );
        expect(result.success, isTrue, reason: 'Failed on iteration $i');
        expect(
          CrcPatcher.computeCrc32(result.patchedData!),
          CrcPatcher.computeCrc32(original),
          reason: 'CRC mismatch on iteration $i',
        );
      }
    });
  });
}
