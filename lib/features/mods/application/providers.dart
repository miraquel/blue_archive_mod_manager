import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bamm/features/mods/application/mod_apply_controller.dart';
import 'package:bamm/features/mods/application/mod_import_controller.dart';
import 'package:bamm/features/mods/application/mod_library_controller.dart';
import 'package:bamm/features/mods/domain/entities/mod_entry.dart';
import 'package:bamm/features/mods/domain/repositories/mod_repository.dart';
import 'package:bamm/features/mods/infrastructure/local_mod_repository.dart';
import 'package:bamm/features/mods/infrastructure/mod_staging_store.dart';

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

final modLibraryControllerProvider =
    AsyncNotifierProvider<ModLibraryController, List<ModEntry>>(
  ModLibraryController.new,
);

final modImportControllerProvider =
    NotifierProvider<ModImportController, ModImportState>(
  ModImportController.new,
);

final modApplyControllerProvider =
    NotifierProvider<ModApplyController, ModApplyState>(
  ModApplyController.new,
);
