import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bamm/core/constants/app_constants.dart';
import 'package:bamm/features/launch/application/providers.dart';

class LaunchController extends Notifier<LaunchState> {
  @override
  LaunchState build() => const LaunchState();

  Future<void> launchGame(GameRegion region) async {
    state = state.copyWith(isLaunching: true, error: null);
    try {
      final repo = ref.read(launcherRepositoryProvider);
      final success = await repo.launchGame(region);
      state = state.copyWith(
        isLaunching: false,
        lastLaunchSuccess: success,
        error: success ? null : 'Failed to launch game',
      );
    } catch (e) {
      state = state.copyWith(
        isLaunching: false,
        error: e.toString(),
      );
    }
  }
}

class LaunchState {
  final bool isLaunching;
  final bool? lastLaunchSuccess;
  final String? error;

  const LaunchState({
    this.isLaunching = false,
    this.lastLaunchSuccess,
    this.error,
  });

  LaunchState copyWith({
    bool? isLaunching,
    bool? lastLaunchSuccess,
    String? error,
  }) {
    return LaunchState(
      isLaunching: isLaunching ?? this.isLaunching,
      lastLaunchSuccess: lastLaunchSuccess ?? this.lastLaunchSuccess,
      error: error,
    );
  }
}
