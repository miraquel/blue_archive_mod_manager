import 'package:flutter_test/flutter_test.dart';

import 'package:bamm/features/recovery/domain/entities/manifest_resource.dart';
import 'package:bamm/features/recovery/domain/services/repair_diff_engine.dart';
import 'package:bamm/features/shizuku/domain/shizuku_bridge.dart';

/// Fake Shizuku bridge for testing the diff engine without real device access.
class FakeShizukuBridge implements ShizukuBridge {
  final Map<String, int> files; // path -> size

  FakeShizukuBridge(this.files);

  @override
  Future<bool> fileExists(String path) async => files.containsKey(path);

  @override
  Future<int> getFileSize(String path) async => files[path] ?? -1;

  @override
  Future<bool> isDirectory(String path) async => false;

  // Unused methods — satisfy the interface.
  @override
  Future<bool> pingBinder() async => true;
  @override
  Future<bool> checkPermission() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<int> getVersion() async => 1;
  @override
  Future<bool> bindService() async => true;
  @override
  Future<bool> unbindService() async => true;
  @override
  Future<bool> isServiceBound() async => true;
  @override
  Future<List<int>?> readFile(String path) async => null;
  @override
  Future<bool> writeFile(String path, List<int> data) async => true;
  @override
  Future<bool> copyFile(String source, String dest) async => true;
  @override
  Future<bool> deleteFile(String path) async => true;
  @override
  Future<List<String>> listFiles(String directoryPath) async => [];
  @override
  Future<bool> createDirectory(String path) async => true;
  @override
  Future<bool> isPackageInstalled(String packageName) async => false;
  @override
  Future<bool> launchPackage(String packageName) async => false;
  @override
  Stream<void> get onBinderReceived => const Stream.empty();
  @override
  Stream<void> get onBinderDead => const Stream.empty();
}

void main() {
  const engine = RepairDiffEngine();

  const gameDataPath = '/storage/emulated/0/Android/data/com.nexon.bluearchive'
      '/files/PUB/Resource/GameData';

  ManifestResource resource(String path, int size) {
    return ManifestResource(
      group: 'g',
      resourcePath: path,
      resourceSize: size,
      resourceHash: '',
    );
  }

  group('RepairDiffEngine', () {
    test('all files match → isClean', () async {
      final manifest = [
        resource('Android/a.bundle', 100),
        resource('Android/b.bundle', 200),
      ];
      final bridge = FakeShizukuBridge({
        '$gameDataPath/Android/a.bundle': 100,
        '$gameDataPath/Android/b.bundle': 200,
      });

      final diff = await engine.computeDiff(
        bridge: bridge,
        gameDataPath: gameDataPath,
        manifest: manifest,
      );

      expect(diff.isClean, isTrue);
      expect(diff.totalManifestFiles, 2);
      expect(diff.okFiles.length, 2);
    });

    test('missing file detected', () async {
      final manifest = [
        resource('Android/exists.bundle', 100),
        resource('Android/missing.bundle', 200),
      ];
      final bridge = FakeShizukuBridge({
        '$gameDataPath/Android/exists.bundle': 100,
      });

      final diff = await engine.computeDiff(
        bridge: bridge,
        gameDataPath: gameDataPath,
        manifest: manifest,
      );

      expect(diff.isClean, isFalse);
      expect(diff.missingFiles.length, 1);
      expect(
        diff.missingFiles.first.manifestEntry.resourcePath,
        'Android/missing.bundle',
      );
    });

    test('size mismatch detected', () async {
      final manifest = [
        resource('Android/changed.bundle', 500),
      ];
      final bridge = FakeShizukuBridge({
        '$gameDataPath/Android/changed.bundle': 999,
      });

      final diff = await engine.computeDiff(
        bridge: bridge,
        gameDataPath: gameDataPath,
        manifest: manifest,
      );

      expect(diff.isClean, isFalse);
      expect(diff.mismatchedFiles.length, 1);
      expect(diff.mismatchedFiles.first.localSize, 999);
    });

    test('empty manifest → clean and empty', () async {
      final bridge = FakeShizukuBridge({});

      final diff = await engine.computeDiff(
        bridge: bridge,
        gameDataPath: gameDataPath,
        manifest: [],
      );

      expect(diff.isClean, isTrue);
      expect(diff.totalManifestFiles, 0);
    });

    test('progress callback fires for each file', () async {
      final manifest = [
        resource('Android/a.bundle', 10),
        resource('Android/b.bundle', 20),
        resource('Android/c.bundle', 30),
      ];
      final bridge = FakeShizukuBridge({
        '$gameDataPath/Android/a.bundle': 10,
        '$gameDataPath/Android/b.bundle': 20,
        '$gameDataPath/Android/c.bundle': 30,
      });

      final progressCalls = <(int, int)>[];
      await engine.computeDiff(
        bridge: bridge,
        gameDataPath: gameDataPath,
        manifest: manifest,
        onProgress: (current, total) => progressCalls.add((current, total)),
      );

      expect(progressCalls.length, 3);
      expect(progressCalls[0], (1, 3));
      expect(progressCalls[1], (2, 3));
      expect(progressCalls[2], (3, 3));
    });

    test('mixed results classifies each file correctly', () async {
      final manifest = [
        resource('Android/ok.bundle', 100),
        resource('Android/mismatch.bundle', 200),
        resource('Android/gone.bundle', 300),
      ];
      final bridge = FakeShizukuBridge({
        '$gameDataPath/Android/ok.bundle': 100,
        '$gameDataPath/Android/mismatch.bundle': 999,
      });

      final diff = await engine.computeDiff(
        bridge: bridge,
        gameDataPath: gameDataPath,
        manifest: manifest,
      );

      expect(diff.okFiles.length, 1);
      expect(diff.mismatchedFiles.length, 1);
      expect(diff.missingFiles.length, 1);
      expect(diff.repairableCount, 2);
    });
  });
}
