import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bamm/features/mods/application/mod_apply_controller.dart';
import 'package:bamm/features/mods/application/mod_import_controller.dart';
import 'package:bamm/features/mods/application/mod_library_controller.dart';
import 'package:bamm/features/mods/domain/entities/global_android_asset_index.dart';
import 'package:bamm/features/mods/domain/entities/global_android_asset_index_snapshot.dart';
import 'package:bamm/features/mods/domain/entities/mod_entry.dart';
import 'package:bamm/features/mods/domain/repositories/global_android_asset_index_repository.dart';
import 'package:bamm/features/mods/domain/repositories/mod_repository.dart';
import 'package:bamm/features/mods/domain/repositories/student_index_repository.dart';
import 'package:bamm/features/mods/domain/services/global_android_asset_index_builder.dart';
import 'package:bamm/features/mods/domain/services/mod_asset_metadata_parser.dart';
import 'package:bamm/features/mods/domain/services/mod_compatibility_validator.dart';
import 'package:bamm/features/mods/domain/services/mod_student_matcher.dart';
import 'package:bamm/features/mods/infrastructure/bundled_global_android_asset_index_loader.dart';
import 'package:bamm/features/mods/infrastructure/local_global_android_asset_index_repository.dart';
import 'package:bamm/features/mods/infrastructure/local_mod_repository.dart';
import 'package:bamm/features/mods/infrastructure/mod_staging_store.dart';
import 'package:bamm/features/mods/infrastructure/schale_student_index_repository.dart';

/// Provides the SharedPreferences instance.
///
/// Must be overridden in [ProviderScope] at app startup:
/// ```dart
/// final prefs = await SharedPreferences.getInstance();
/// runApp(
///   ProviderScope(
///     overrides: [
///       sharedPreferencesProvider.overrideWithValue(prefs),
///     ],
///     child: const BammApp(),
///   ),
/// );
/// ```
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with a real '
    'SharedPreferences instance at app startup.',
  );
});

final modRepositoryProvider = Provider<ModRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalModRepository(prefs);
});

final modStagingStoreProvider = Provider<ModStagingStore>((ref) {
  return ModStagingStore();
});

final studentIndexRepositoryProvider = Provider<StudentIndexRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SchaleStudentIndexRepository(prefs);
});

final modStudentMatcherProvider = Provider<ModStudentMatcher>((ref) {
  return const ModStudentMatcher();
});

final modAssetMetadataParserProvider = Provider<ModAssetMetadataParser>((ref) {
  return const ModAssetMetadataParser();
});

final bundledGlobalAndroidAssetIndexLoaderProvider =
    Provider<BundledGlobalAndroidAssetIndexLoader>((ref) {
      return const BundledGlobalAndroidAssetIndexLoader();
    });

final globalAndroidAssetIndexRepositoryProvider =
    Provider<GlobalAndroidAssetIndexRepository>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      final bundledLoader = ref.watch(
        bundledGlobalAndroidAssetIndexLoaderProvider,
      );
      return LocalGlobalAndroidAssetIndexRepository(prefs, bundledLoader);
    });

final globalAndroidAssetIndexSnapshotProvider =
    FutureProvider<GlobalAndroidAssetIndexSnapshot>((ref) async {
      final repository = ref.watch(globalAndroidAssetIndexRepositoryProvider);
      return repository.loadSnapshot();
    });

final globalAndroidAssetIndexProvider = FutureProvider<GlobalAndroidAssetIndex>(
  (ref) async {
    final snapshot = await ref.watch(
      globalAndroidAssetIndexSnapshotProvider.future,
    );
    return snapshot.index;
  },
);

final globalAndroidAssetIndexBuilderProvider =
    Provider<GlobalAndroidAssetIndexBuilder>((ref) {
      final parser = ref.watch(modAssetMetadataParserProvider);
      return GlobalAndroidAssetIndexBuilder(parser);
    });

final modCompatibilityValidatorProvider = Provider<ModCompatibilityValidator>((
  ref,
) {
  return const ModCompatibilityValidator();
});

final modLibraryControllerProvider =
    AsyncNotifierProvider<ModLibraryController, List<ModEntry>>(
      ModLibraryController.new,
    );

final modImportControllerProvider =
    NotifierProvider<ModImportController, ModImportState>(
      ModImportController.new,
    );

final modApplyControllerProvider =
    NotifierProvider<ModApplyController, ModApplyState>(ModApplyController.new);
