import 'dart:async';

import 'package:bamm/features/catalog/application/providers.dart';
import 'package:bamm/features/catalog/domain/entities/asset_mapping.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages the lifecycle of asset-name mappings.
class MappingController extends AsyncNotifier<MappingState> {
  @override
  Future<MappingState> build() async {
    final repo = ref.watch(mappingRepositoryProvider);
    final hasMappings = await repo.hasMappings();
    if (hasMappings) {
      final mappings = await repo.loadMappings();
      return MappingState(mappings: mappings, isLoaded: true);
    }
    return const MappingState();
  }

  /// Opens a file picker to import a Mapping.json file.
  Future<void> importMappingFile() async {
    final repo = ref.read(mappingRepositoryProvider);
    final previous = state.valueOrNull ?? const MappingState();

    state = AsyncData(previous.copyWith(isImporting: true, error: null));

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        // User cancelled the picker
        state = AsyncData(previous.copyWith(isImporting: false));
        return;
      }

      final filePath = result.files.single.path!;
      await repo.importMappingsFromFile(filePath);
      final mappings = await repo.loadMappings();

      state = AsyncData(
        MappingState(mappings: mappings, isLoaded: true),
      );
    } catch (e) {
      state = AsyncData(
        previous.copyWith(isImporting: false, error: e.toString()),
      );
    }
  }

  /// Resolves a CRC hash to a human-readable asset name, or `null` if unknown.
  String? resolveAssetName(String crcHash) {
    final current = state.valueOrNull;
    if (current == null || !current.isLoaded) return null;
    return current.lookupMap[crcHash]?.assetName;
  }

  /// Removes all stored mappings.
  Future<void> clearMappings() async {
    final repo = ref.read(mappingRepositoryProvider);
    await repo.clearMappings();
    state = const AsyncData(MappingState());
  }
}

/// Immutable state for [MappingController].
class MappingState {
  final List<AssetMapping> mappings;
  final bool isLoaded;
  final bool isImporting;
  final String? error;

  const MappingState({
    this.mappings = const [],
    this.isLoaded = false,
    this.isImporting = false,
    this.error,
  });

  MappingState copyWith({
    List<AssetMapping>? mappings,
    bool? isLoaded,
    bool? isImporting,
    String? error,
  }) {
    return MappingState(
      mappings: mappings ?? this.mappings,
      isLoaded: isLoaded ?? this.isLoaded,
      isImporting: isImporting ?? this.isImporting,
      error: error ?? this.error,
    );
  }

  /// Pre-built lookup map keyed by CRC hash for O(1) resolution.
  Map<String, AssetMapping> get lookupMap => {
        for (final m in mappings) m.crcHash: m,
      };
}
