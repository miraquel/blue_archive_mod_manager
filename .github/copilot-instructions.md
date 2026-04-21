# BAMM Copilot Instructions

## Build, test, and lint

- `flutter analyze`
- `flutter test`
- `flutter test test/crc_patcher_test.dart`
- `flutter build apk`
- `flutter run`
- `dart run build_runner build --delete-conflicting-outputs`
- `dart run build_runner watch --delete-conflicting-outputs`

## High-level architecture

- BAMM is an **Android-only** Flutter app for managing Blue Archive mods. iOS, web, Linux, macOS, and Windows targets exist because of the default Flutter project layout, but the app logic is centered on Android and Shizuku-backed file access.
- `lib/main.dart` loads `SharedPreferences` before `runApp` and overrides `sharedPreferencesProvider` in the root `ProviderScope`. Many repositories depend on that override instead of creating their own shared-preferences instance.
- The app shell is in `lib/app/`: `router.dart` uses a `GoRouter` indexed-stack shell with three main tabs: Home, Mods, and Settings. `HomeScreen` initializes Shizuku and shows quick actions; `SettingsScreen` hosts mapping import and game recovery actions.
- Features follow a feature-first structure under `lib/features/<feature>/` with `domain`, `application`, `infrastructure`, and `presentation` layers. Dependency wiring lives in each feature's `application/providers.dart`.
- All privileged game-file and package operations go through the `ShizukuBridge` Dart interface. The concrete path is:
  `ShizukuBridge` -> `MethodChannelShizukuBridge` -> `ShizukuBridgePlugin.kt` -> `IFileService.aidl` -> `FileService.kt`.
- Mod application is coordinated by `ModApplyController`: detect the accessible game install, read the original file through Shizuku, create a backup if one does not already exist for that target, CRC-patch the mod bytes to match the original file, write the patched bytes back, then mark the mod as applied in the local repository.
- Recovery is coordinated by `RepairController`: read `BundleRevision` from the installed game data, fetch the latest Nexon version/manifest, diff local files with `RepairDiffEngine`, download only the files that need repair, and write them back through Shizuku. The same controller also restores all BAMM backups.

## Key conventions

- Use the existing Riverpod style: this codebase currently uses hand-written `Provider`, `NotifierProvider`, and `AsyncNotifierProvider` declarations in `providers.dart`. Do not assume `@riverpod` or generated `.g.dart` providers already exist just because `build_runner` dependencies are present.
- Keep Shizuku changes synchronized across Dart and Android. If you add or change bridge methods, update the Dart interface, the method-channel implementation, the Flutter plugin, the AIDL contract, and the native `FileService` together.
- Treat device game-data paths as POSIX Android paths such as `/storage/emulated/0/Android/data/...`. For game-file paths, prefer POSIX-style joining and comparisons; local app-managed storage uses `path_provider` and the app documents directory instead.
- `listFiles` and `listFilesPage` are intentionally different: `listFiles` returns absolute child paths, while `listFilesPage` returns child names only. Recovery scanning code depends on that distinction.
- `ModEntry.targetFile` is derived. `targetFileOverride` wins when present; otherwise the mod falls back to `originalFileName`. Serialization keeps both `targetFile` and `targetFileOverride` for backward compatibility.
- Mod metadata is stored in `SharedPreferences`, while imported files, backups, mapping data, and rebuilt asset-index JSON live in the app documents directory. There is no database layer for mods or recovery state.
- Backups represent the first-seen original game file. Restore flows treat the earliest backup for a path as the source of truth.
- `RepairDiffEngine` matches manifest entries by full relative path, not by basename, and it falls back to direct `fileExists` / size / hash checks when recursive listings miss files. Its `trackedPaths` parameter is currently retained for API compatibility rather than active filtering.
- The live Settings recovery flow uses `RepairController`. `ValidatorIndexController` still exists in the tree, but `lib/features/settings/application/providers.dart` now re-exports recovery providers instead of wiring that older controller into the screen.
- The global asset index uses `assets/data/global_android_asset_index.json` as a bundled fallback. A rebuilt index is saved as an override JSON in the app documents directory and loaded before the bundled asset.
- Most game-facing flows currently operate on the first accessible **Global Android** install (`GameRegion.global` / `com.nexon.bluearchive`), even though JP constants also exist.
- For recovery and bridge unit tests, the existing pattern is to fake `ShizukuBridge` in pure Dart tests instead of relying on a real device or method channel.
