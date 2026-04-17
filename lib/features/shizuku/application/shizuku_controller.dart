import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bamm/core/logging/app_logger.dart';
import 'package:bamm/features/shizuku/application/providers.dart';
import 'package:bamm/features/shizuku/application/shizuku_state.dart';
import 'package:bamm/features/shizuku/domain/shizuku_bridge.dart';

/// Manages the Shizuku lifecycle and exposes the current [ShizukuState].
class ShizukuController extends Notifier<ShizukuState> {
  static const _tag = 'ShizukuController';

  @override
  ShizukuState build() {
    final bridge = ref.watch(shizukuBridgeProvider);
    _listenToEvents(bridge);
    return const ShizukuState();
  }

  // ---------------------------------------------------------------------------
  // Event listeners
  // ---------------------------------------------------------------------------

  void _listenToEvents(ShizukuBridge bridge) {
    final binderSub = bridge.onBinderReceived.listen((_) {
      AppLogger.info('Binder received – updating state', tag: _tag);
      state = state.copyWith(
        status: ShizukuStatus.binderAlive,
        errorMessage: null,
      );
    });

    final deadSub = bridge.onBinderDead.listen((_) {
      AppLogger.warning('Binder dead – resetting state', tag: _tag);
      state = state.copyWith(
        status: ShizukuStatus.installed,
        errorMessage: 'Shizuku binder died',
      );
    });

    ref.onDispose(() {
      binderSub.cancel();
      deadSub.cancel();
    });
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Run the full initialisation sequence: ping → check permission → bind.
  Future<void> initialize() async {
    final bridge = ref.read(shizukuBridgeProvider);
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // 1. Ping
      final alive = await bridge.pingBinder();
      if (!alive) {
        state = state.copyWith(
          status: ShizukuStatus.notInstalled,
          isLoading: false,
          errorMessage: 'Shizuku binder is not available',
        );
        return;
      }
      state = state.copyWith(status: ShizukuStatus.binderAlive);

      // 2. Version
      final version = await bridge.getVersion();
      state = state.copyWith(version: version);

      // 3. Permission
      final hasPermission = await bridge.checkPermission();
      if (!hasPermission) {
        state = state.copyWith(
          status: ShizukuStatus.binderAlive,
          isLoading: false,
        );
        return;
      }
      state = state.copyWith(status: ShizukuStatus.permissionGranted);

      // 4. Bind service
      final bound = await bridge.bindService();
      state = state.copyWith(
        status: bound
            ? ShizukuStatus.serviceBound
            : ShizukuStatus.permissionGranted,
        isLoading: false,
      );
    } catch (e, st) {
      AppLogger.error(
        'Initialization failed',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Request Shizuku permission from the user.
  Future<void> requestPermission() async {
    final bridge = ref.read(shizukuBridgeProvider);
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final granted = await bridge.requestPermission();
      state = state.copyWith(
        status: granted
            ? ShizukuStatus.permissionGranted
            : state.status,
        isLoading: false,
        errorMessage: granted ? null : 'Permission denied by user',
      );
    } catch (e, st) {
      AppLogger.error(
        'requestPermission failed',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Bind to the privileged UserService.
  Future<void> bindService() async {
    final bridge = ref.read(shizukuBridgeProvider);
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final bound = await bridge.bindService();
      state = state.copyWith(
        status: bound
            ? ShizukuStatus.serviceBound
            : state.status,
        isLoading: false,
        errorMessage: bound ? null : 'Failed to bind service',
      );
    } catch (e, st) {
      AppLogger.error(
        'bindService failed',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Unbind from the privileged UserService.
  Future<void> unbindService() async {
    final bridge = ref.read(shizukuBridgeProvider);
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await bridge.unbindService();
      state = state.copyWith(
        status: ShizukuStatus.permissionGranted,
        isLoading: false,
      );
    } catch (e, st) {
      AppLogger.error(
        'unbindService failed',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}
