import 'package:flutter_test/flutter_test.dart';

import 'package:bamm/features/recovery/domain/entities/manifest_resource.dart';
import 'package:bamm/features/recovery/domain/entities/repair_diff.dart';
import 'package:bamm/features/recovery/domain/entities/repair_result.dart';
import 'package:bamm/features/recovery/domain/entities/version_info.dart';

void main() {
  // ---------------------------------------------------------------------------
  // ManifestResource
  // ---------------------------------------------------------------------------
  group('ManifestResource', () {
    test('fileName extracts last path segment', () {
      const resource = ManifestResource(
        group: 'MediaResources',
        resourcePath: 'Android/bundleDownloadInfo/TableBundles/ExcelDB/foo.bundle',
        resourceSize: 1024,
        resourceHash: 'abc123',
      );
      expect(resource.fileName, 'foo.bundle');
    });

    test('fileName returns full path when no slash', () {
      const resource = ManifestResource(
        group: 'Root',
        resourcePath: 'catalog.json',
        resourceSize: 256,
        resourceHash: 'def456',
      );
      expect(resource.fileName, 'catalog.json');
    });

    test('gameDataRelativePath keeps Nexon manifest paths unchanged', () {
      const resource = ManifestResource(
        group: 'Preload',
        resourcePath: 'Preload/TableBundles/ExcelDB/foo.bytes',
        resourceSize: 256,
        resourceHash: 'def456',
      );
      expect(
        resource.gameDataRelativePath,
        'Preload/TableBundles/ExcelDB/foo.bytes',
      );
    });

    test('gameDataRelativePath strips legacy Android prefix', () {
      const resource = ManifestResource(
        group: 'Root',
        resourcePath: 'Android/Preload/TableBundles/foo.bytes',
        resourceSize: 256,
        resourceHash: 'ghi789',
      );
      expect(
        resource.gameDataRelativePath,
        'Preload/TableBundles/foo.bytes',
      );
    });

    test('fromJson round-trips correctly', () {
      const resource = ManifestResource(
        group: 'g1',
        resourcePath: 'Android/test.bundle',
        resourceSize: 2048,
        resourceHash: 'hash_value',
      );
      final json = resource.toJson();
      final restored = ManifestResource.fromJson(json);
      expect(restored.group, resource.group);
      expect(restored.resourcePath, resource.resourcePath);
      expect(restored.resourceSize, resource.resourceSize);
      expect(restored.resourceHash, resource.resourceHash);
    });

    test('equality is based on resourcePath', () {
      const a = ManifestResource(
        group: 'g1',
        resourcePath: 'Android/same.bundle',
        resourceSize: 100,
        resourceHash: 'h1',
      );
      const b = ManifestResource(
        group: 'g2',
        resourcePath: 'Android/same.bundle',
        resourceSize: 200,
        resourceHash: 'h2',
      );
      expect(a, equals(b));
    });
  });

  // ---------------------------------------------------------------------------
  // VersionInfo
  // ---------------------------------------------------------------------------
  group('VersionInfo', () {
    test('fromJson parses Nexon-style response', () {
      final json = {
        'latest_build_version': '1.70.300000',
        'latest_build_number': '300000',
        'patch': {
          'patch_version': 42,
          'resource_path':
              'https://cdn.example.com/patch/v42/manifest.json',
        },
      };
      final info = VersionInfo.fromJson(json);
      expect(info.latestBuildVersion, '1.70.300000');
      expect(info.latestBuildNumber, '300000');
      expect(info.patchVersion, 42);
      expect(info.resourcePath,
          'https://cdn.example.com/patch/v42/manifest.json');
    });

    test('resourceBasePath strips last path segment', () {
      final info = VersionInfo.fromJson({
        'latest_build_version': '1.0',
        'latest_build_number': '1',
        'patch': {
          'patch_version': 1,
          'resource_path': 'https://cdn.example.com/patch/v1/manifest.json',
        },
      });
      expect(info.resourceBasePath, 'https://cdn.example.com/patch/v1');
    });
  });

  // ---------------------------------------------------------------------------
  // RepairDiff
  // ---------------------------------------------------------------------------
  group('RepairDiff', () {
    const resourceA = ManifestResource(
      group: 'g', resourcePath: 'Android/a.bundle',
      resourceSize: 100, resourceHash: '',
    );
    const resourceB = ManifestResource(
      group: 'g', resourcePath: 'Android/b.bundle',
      resourceSize: 200, resourceHash: '',
    );
    const resourceC = ManifestResource(
      group: 'g', resourcePath: 'Android/c.bundle',
      resourceSize: 300, resourceHash: '',
    );

    test('isClean when all files are ok', () {
      final diff = RepairDiff(
        entries: [
          FileDiffEntry(
            manifestEntry: resourceA,
            status: FileDiffStatus.ok,
            localSize: 100,
          ),
        ],
        totalManifestFiles: 1,
        scannedAt: DateTime.now(),
      );
      expect(diff.isClean, isTrue);
      expect(diff.repairableCount, 0);
    });

    test('reports missing files', () {
      final diff = RepairDiff(
        entries: [
          FileDiffEntry(
            manifestEntry: resourceA,
            status: FileDiffStatus.missing,
          ),
          FileDiffEntry(
            manifestEntry: resourceB,
            status: FileDiffStatus.ok,
            localSize: 200,
          ),
        ],
        totalManifestFiles: 2,
        scannedAt: DateTime.now(),
      );
      expect(diff.isClean, isFalse);
      expect(diff.missingFiles.length, 1);
      expect(diff.repairableCount, 1);
    });

    test('reports size mismatches', () {
      final diff = RepairDiff(
        entries: [
          FileDiffEntry(
            manifestEntry: resourceC,
            status: FileDiffStatus.sizeMismatch,
            localSize: 999,
          ),
        ],
        totalManifestFiles: 1,
        scannedAt: DateTime.now(),
      );
      expect(diff.mismatchedFiles.length, 1);
      expect(diff.repairableCount, 1);
    });

    test('mixed status counts are correct', () {
      final diff = RepairDiff(
        entries: [
          FileDiffEntry(
            manifestEntry: resourceA,
            status: FileDiffStatus.ok,
            localSize: 100,
          ),
          FileDiffEntry(
            manifestEntry: resourceB,
            status: FileDiffStatus.missing,
          ),
          FileDiffEntry(
            manifestEntry: resourceC,
            status: FileDiffStatus.sizeMismatch,
            localSize: 123,
          ),
        ],
        totalManifestFiles: 3,
        scannedAt: DateTime.now(),
      );
      expect(diff.okFiles.length, 1);
      expect(diff.missingFiles.length, 1);
      expect(diff.mismatchedFiles.length, 1);
      expect(diff.repairableCount, 2);
      expect(diff.isClean, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // RepairResult
  // ---------------------------------------------------------------------------
  group('RepairResult', () {
    test('isFullSuccess when all succeed and no error', () {
      const result = RepairResult(attemptedCount: 3, successCount: 3);
      expect(result.isFullSuccess, isTrue);
      expect(result.isPartialSuccess, isFalse);
    });

    test('isPartialSuccess when some fail', () {
      const result = RepairResult(
        attemptedCount: 3,
        successCount: 2,
        failedFiles: ['a.bundle'],
      );
      expect(result.isFullSuccess, isFalse);
      expect(result.isPartialSuccess, isTrue);
      expect(result.failureCount, 1);
    });

    test('zero success is neither full nor partial', () {
      const result = RepairResult(
        attemptedCount: 0,
        successCount: 0,
      );
      expect(result.isFullSuccess, isFalse);
      expect(result.isPartialSuccess, isFalse);
    });

    test('error message prevents full success', () {
      const result = RepairResult(
        attemptedCount: 1,
        successCount: 1,
        errorMessage: 'Something went wrong',
      );
      expect(result.isFullSuccess, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // FileDiffEntry.needsRepair
  // ---------------------------------------------------------------------------
  group('FileDiffEntry', () {
    const resource = ManifestResource(
      group: 'g',
      resourcePath: 'Android/test.bundle',
      resourceSize: 100,
      resourceHash: '',
    );

    test('needsRepair is true for missing', () {
      const entry = FileDiffEntry(
        manifestEntry: resource,
        status: FileDiffStatus.missing,
      );
      expect(entry.needsRepair, isTrue);
    });

    test('needsRepair is true for sizeMismatch', () {
      const entry = FileDiffEntry(
        manifestEntry: resource,
        status: FileDiffStatus.sizeMismatch,
        localSize: 50,
      );
      expect(entry.needsRepair, isTrue);
    });

    test('needsRepair is false for ok', () {
      const entry = FileDiffEntry(
        manifestEntry: resource,
        status: FileDiffStatus.ok,
        localSize: 100,
      );
      expect(entry.needsRepair, isFalse);
    });
  });
}
