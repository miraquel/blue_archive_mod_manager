import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bamm/features/recovery/domain/entities/manifest_resource.dart';
import 'package:bamm/features/recovery/domain/entities/repair_diff.dart';
import 'package:bamm/features/recovery/domain/services/repair_diff_engine.dart';
import 'package:bamm/features/shizuku/domain/shizuku_bridge.dart';

/// Fake Shizuku bridge for testing the diff engine without real device access.
///
/// Files are registered by their FULL absolute path matching the expected
/// device layout (i.e. `$gameDataPath/<gameDataRelativePath>`).
class FakeShizukuBridge implements ShizukuBridge {
  final Map<String, int> files; // path → size

  FakeShizukuBridge(this.files);

  @override
  Future<bool> fileExists(String path) async => files.containsKey(path);

  @override
  Future<int> getFileSize(String path) async => files[path] ?? -1;

  @override
  Future<bool> isDirectory(String path) async {
    final prefix = '$path/';
    return files.keys.any((filePath) => filePath.startsWith(prefix));
  }

  // Unused lifecycle methods — satisfy the interface.
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
  Future<List<int>?> readFile(String path) async {
    final size = files[path];
    if (size == null) return null;
    return List<int>.filled(size, 0);
  }

  @override
  Future<bool> writeFile(String path, List<int> data) async => true;
  @override
  Future<bool> copyFile(String source, String dest) async => true;
  @override
  Future<bool> deleteFile(String path) async => true;

  @override
  Future<List<String>> listFiles(String directoryPath) async {
    final names = await listFilesPage(directoryPath, 0, files.length);
    return names
        .map((name) => '$directoryPath/$name')
        .toList(growable: false);
  }

  @override
  Future<List<String>> listFilesPage(
    String directoryPath,
    int offset,
    int limit,
  ) async {
    final children = <String>{};
    final prefix = '$directoryPath/';

    for (final filePath in files.keys) {
      if (!filePath.startsWith(prefix)) continue;

      final remainder = filePath.substring(prefix.length);
      if (remainder.isEmpty) continue;

      final nextSlash = remainder.indexOf('/');
      if (nextSlash == -1) {
        children.add(remainder);
      } else {
        children.add(remainder.substring(0, nextSlash));
      }
    }

    final sorted = children.toList(growable: false)..sort();
    if (offset >= sorted.length || limit <= 0) return const [];
    final end =
        (offset + limit) > sorted.length ? sorted.length : offset + limit;
    return sorted.sublist(offset, end);
  }

  @override
  Future<bool> createDirectory(String path) async => true;
  @override
  Future<bool> isPackageInstalled(String packageName) async => false;
  @override
  Future<bool> launchPackage(String packageName) async => false;

  @override
  Future<String?> getFileMd5(String path) async {
    final size = files[path];
    if (size == null) return null;
    return md5.convert(List<int>.filled(size, 0)).toString();
  }

  @override
  Stream<void> get onBinderReceived => const Stream.empty();
  @override
  Stream<void> get onBinderDead => const Stream.empty();
}

void main() {
  const engine = RepairDiffEngine();

  const gameDataPath = '/storage/emulated/0/Android/data/com.nexon.bluearchive'
      '/files/PUB/Resource/GameData/Android';

  String hashForSize(int size) =>
      md5.convert(List<int>.filled(size, 0)).toString();

  /// Build a [ManifestResource] whose default hash matches zero-filled bytes of
  /// [size] — so a [FakeShizukuBridge] file of the same size always passes the
  /// hash check unless [hash] is overridden.
  ManifestResource resource(String path, int size, {String? hash}) {
    return ManifestResource(
      group: 'g',
      resourcePath: path,
      resourceSize: size,
      resourceHash: hash ?? hashForSize(size),
    );
  }

  group('RepairDiffEngine', () {
    test('all files match → isClean', () async {
      final manifest = [
        resource('Preload/folder/a.bundle', 100),
        resource('MediaResources/folder/b.bundle', 200),
      ];
      // Files stored at paths matching gameDataRelativePath.
      final bridge = FakeShizukuBridge({
        '$gameDataPath/Preload/folder/a.bundle': 100,
        '$gameDataPath/MediaResources/folder/b.bundle': 200,
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

    test('missing file detected via trackedPaths (fileExists fallback)',
        () async {
      final manifest = [resource('Preload/missing.bundle', 200)];
      final bridge = FakeShizukuBridge({
        '$gameDataPath/Preload/existing.bundle': 100,
      });

      // trackedPaths is now informational only; missing detection uses
      // fileExists under the hood and does not depend on this parameter.
      final diff = await engine.computeDiff(
        bridge: bridge,
        gameDataPath: gameDataPath,
        manifest: manifest,
        trackedPaths: const {
          '$gameDataPath/Preload/missing.bundle',
        },
      );

      expect(diff.isClean, isFalse);
      expect(diff.missingFiles.length, 1);
      expect(
        diff.missingFiles.first.manifestEntry.resourcePath,
        'Preload/missing.bundle',
      );
    });

    test('missing file detected without trackedPaths (manifest-forward pass)',
        () async {
      final manifest = [
        resource('Preload/missing.bundle', 200),
        resource('Preload/existing.bundle', 100),
      ];
      final bridge = FakeShizukuBridge({
        '$gameDataPath/Preload/existing.bundle': 100,
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
        'Preload/missing.bundle',
      );
      expect(
        diff.missingFiles.first.localPath,
        '$gameDataPath/Preload/missing.bundle',
      );
      expect(diff.totalManifestFiles, 2);
    });

    test('size mismatch detected', () async {
      final manifest = [
        resource('MediaResources/changed.bundle', 500),
      ];
      final bridge = FakeShizukuBridge({
        '$gameDataPath/MediaResources/changed.bundle': 999,
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

    test('hash mismatch detected even when size matches', () async {
      final manifest = [
        resource(
          'MediaResources/hash.bundle',
          100,
          hash: 'ffffffffffffffffffffffffffffffff',
        ),
      ];
      final bridge = FakeShizukuBridge({
        '$gameDataPath/MediaResources/hash.bundle': 100,
      });

      final diff = await engine.computeDiff(
        bridge: bridge,
        gameDataPath: gameDataPath,
        manifest: manifest,
      );

      expect(diff.isClean, isFalse);
      expect(diff.mismatchedFiles.length, 1);
      expect(diff.mismatchedFiles.first.status, FileDiffStatus.hashMismatch);
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

    test('progress callback fires once per manifest entry', () async {
      final manifest = [
        resource('Preload/a.bundle', 10),
        resource('Preload/b.bundle', 20),
        resource('Preload/c.bundle', 30),
      ];
      final bridge = FakeShizukuBridge({
        '$gameDataPath/Preload/a.bundle': 10,
        '$gameDataPath/Preload/b.bundle': 20,
        '$gameDataPath/Preload/c.bundle': 30,
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
        resource('Preload/ok.bundle', 100),
        resource('MediaResources/mismatch.bundle', 200),
        resource('TableBundles/gone.bundle', 300),
      ];
      final bridge = FakeShizukuBridge({
        '$gameDataPath/Preload/ok.bundle': 100,
        '$gameDataPath/MediaResources/mismatch.bundle': 999, // wrong size
        // gone.bundle intentionally absent
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

    test('legacy Android-prefixed resource paths are normalized', () async {
      final manifest = [
        resource('Android/Preload/a.bundle', 100),
      ];
      // gameDataRelativePath strips the Android/ prefix → Preload/a.bundle
      final bridge = FakeShizukuBridge({
        '$gameDataPath/Preload/a.bundle': 100,
      });

      final diff = await engine.computeDiff(
        bridge: bridge,
        gameDataPath: gameDataPath,
        manifest: manifest,
      );

      expect(diff.isClean, isTrue);
      expect(diff.okFiles.length, 1);
    });

    test('resources with same basename but different paths are independent',
        () async {
      // Unlike the old basename-based approach, full-path matching treats
      // Catalog/BundleRevision and Preload/BundleRevision as separate entries.
      final manifest = [
        resource('Catalog/BundleRevision', 10),
        resource('Preload/BundleRevision', 10),
      ];
      final bridge = FakeShizukuBridge({
        '$gameDataPath/Catalog/BundleRevision': 10,
        '$gameDataPath/Preload/BundleRevision': 10,
      });

      final diff = await engine.computeDiff(
        bridge: bridge,
        gameDataPath: gameDataPath,
        manifest: manifest,
      );

      expect(diff.isClean, isTrue);
      expect(diff.okFiles.length, 2);
      expect(diff.totalManifestFiles, 2);
    });

    test(
        'pre-scan miss falls back to fileExists — file present but not in listing',
        () async {
      // Simulates the Android listing-restriction scenario: the recursive scan
      // returns nothing (empty bridge), but direct fileExists access works.
      // Engine should detect the file as present and check size/hash.
      final manifest = [resource('Preload/a.bundle', 100)];

      // Bridge reports the file via fileExists/getFileSize/getFileMd5 but
      // returns nothing from listFilesPage (empty files map, but we override
      // fileExists to return true for the known path).
      final bridge = _ListingFailsBridge(
        knownFiles: {'$gameDataPath/Preload/a.bundle': 100},
      );

      final diff = await engine.computeDiff(
        bridge: bridge,
        gameDataPath: gameDataPath,
        manifest: manifest,
      );

      expect(diff.isClean, isTrue);
      expect(diff.okFiles.length, 1);
    });
  });
}

/// Fake bridge where directory listing always returns empty (simulating a
/// listing-permission failure) but direct file access works normally.
class _ListingFailsBridge extends FakeShizukuBridge {
  _ListingFailsBridge({required Map<String, int> knownFiles})
      : super(knownFiles);

  @override
  Future<List<String>> listFilesPage(
    String directoryPath,
    int offset,
    int limit,
  ) async =>
      const []; // listing always fails silently
}
