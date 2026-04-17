import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bamm/features/shizuku/application/shizuku_controller.dart';
import 'package:bamm/features/shizuku/application/shizuku_state.dart';
import 'package:bamm/features/shizuku/domain/shizuku_bridge.dart';
import 'package:bamm/features/shizuku/infrastructure/method_channel_shizuku_bridge.dart';

/// Provides the [ShizukuBridge] implementation.
final shizukuBridgeProvider = Provider<ShizukuBridge>((ref) {
  return MethodChannelShizukuBridge();
});

/// Provides the [ShizukuController] notifier and its [ShizukuState].
final shizukuControllerProvider =
    NotifierProvider<ShizukuController, ShizukuState>(
  ShizukuController.new,
);
