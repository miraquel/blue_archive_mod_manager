import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bamm/features/launch/application/launch_controller.dart';
import 'package:bamm/features/launch/domain/launcher_repository.dart';
import 'package:bamm/features/launch/infrastructure/android_launcher_repository.dart';
import 'package:bamm/features/shizuku/application/providers.dart';

final launcherRepositoryProvider = Provider<LauncherRepository>((ref) {
  final bridge = ref.watch(shizukuBridgeProvider);
  return AndroidLauncherRepository(bridge);
});

final launchControllerProvider =
    NotifierProvider<LaunchController, LaunchState>(
  LaunchController.new,
);
