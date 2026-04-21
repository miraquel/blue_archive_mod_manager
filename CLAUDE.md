# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**BAMM** (Blue Archive Mod Manager) is a Flutter/Android app for managing mods for the mobile game Blue Archive. It uses [Shizuku](https://shizuku.rikka.app/) for privileged file access to the game's restricted data directory (`/Android/data/com.nexon.bluearchive/`), enabling mod application, backup, and game file repair without root.

Target platform is **Android only** — iOS/web/desktop targets exist in the repo but are not used.

## Commands

```bash
# Run the app on a connected Android device
flutter run

# Build APK
flutter build apk

# Run all tests
flutter test

# Run a single test file
flutter test test/crc_patcher_test.dart

# Analyze code
flutter analyze

# Code generation (run after modifying freezed/riverpod_generator annotated files)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for code generation
dart run build_runner watch --delete-conflicting-outputs
```

## Architecture

The app follows **feature-first clean architecture** with three layers per feature:

```
lib/
  app/          # App entry, router (GoRouter), theme
  core/         # Shared utilities: Result<T>, AppLogger, AppExceptions, AppConstants
  features/
    catalog/    # Asset mapping: maps mod files to game asset names
    game_data/  # Detects game installs, manages backups via Shizuku
    launch/     # Launches the game package via Shizuku
    mods/       # Mod library: import, validate, apply, restore mods
    recovery/   # Game file repair: scans against Nexon's manifest, re-downloads corrupt/missing files
    settings/   # App settings, validator index refresh
    shizuku/    # Shizuku lifecycle: bind/unbind, permission, event streams
```

Each feature has:
- `domain/entities/` — plain Dart data classes (typically `freezed` or manual `copyWith`)
- `domain/services/` — pure business logic with no platform dependencies
- `domain/repositories/` — abstract interfaces
- `application/` — Riverpod `Notifier`/`AsyncNotifier` controllers + `providers.dart`
- `infrastructure/` — concrete repository implementations (file I/O, HTTP, method channels)
- `presentation/` — Flutter widgets (where present)

## Shizuku Bridge

All privileged file operations go through `ShizukuBridge` (abstract Dart interface at `lib/features/shizuku/domain/shizuku_bridge.dart`). The concrete implementation (`MethodChannelShizukuBridge`) communicates via the `com.example.bamm/shizuku` method channel with `ShizukuBridgePlugin.kt`.

On the Android side, `ShizukuBridgePlugin` binds a `UserService` (`FileService.kt`) that runs in a privileged Shizuku process. All file reads/writes/copies go through `IFileService.aidl` via AIDL IPC. The service must be bound before any file operations — controllers guard this with `isServiceBound()` checks.

## Mod Apply Flow

`ModApplyController.applyMod()` orchestrates:
1. Resolve game data path via `GameDataRepository.detectInstallations()`
2. Read mod file from local storage
3. Read original game file via `ShizukuBridge.readFile()`
4. Create backup (if none exists for that path) via `BackupController`
5. CRC-patch the mod data via `CrcPatcher.manipulateCrc()` so the file's CRC32 matches the original
6. Write patched file back via `ShizukuBridge.writeFile()`

## Game Recovery Flow

`RepairController` implements a scan-and-repair loop:
1. Fetch version info and manifest from Nexon's API (`NexonApiClient`)
2. Diff manifest against device files using `RepairDiffEngine` (skips files tracked by active mods/backups)
3. Download and replace only missing/mismatched files via Shizuku

## State Management

All state is managed with **Riverpod**. Providers are declared in each feature's `providers.dart`. `Notifier<T>` is used for synchronous controllers, `AsyncNotifier<T>` for async ones. Code-generated providers use `@riverpod` annotations — run `build_runner` after changing them.

## Android Native

- `android/app/src/main/aidl/com/example/bamm/IFileService.aidl` — AIDL interface for the privileged file service
- `android/app/src/main/kotlin/com/example/bamm/FileService.kt` — Shizuku UserService implementation
- `android/app/src/main/kotlin/com/example/bamm/ShizukuBridgePlugin.kt` — Flutter plugin, handles method channel routing and Shizuku lifecycle
- `android/app/src/main/kotlin/com/example/bamm/MainActivity.kt` — standard Flutter activity

When modifying `IFileService.aidl`, the AIDL-generated stub is automatically rebuilt by Gradle. The Dart bridge in `MethodChannelShizukuBridge` must be updated to match any new methods.

## Key Domain Rules

- `GameRegion.global` maps to package `com.nexon.bluearchive`; game data lives at `files/PUB/Resource/GameData/Android` inside the app's data dir.
- The CRC patcher appends exactly 4 correction bytes to a mod file so its CRC32 matches the original — this is required by the game's integrity checks.
- Backups store the first (original) copy of a game file before any mod is applied; `restoreMod` always picks the earliest backup by `createdAt`.
- `RepairDiffEngine` excludes paths tracked by applied mods or existing backups from the repair diff so legitimate mod files are not flagged as corrupt.

## Assets

`assets/data/global_android_asset_index.json` is the bundled asset index mapping game asset IDs to filenames. It is loaded by `BundledGlobalAndroidAssetIndexLoader` and serves as a fallback when the network index is unavailable.
