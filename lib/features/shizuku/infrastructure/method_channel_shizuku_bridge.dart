import 'dart:async';

import 'package:flutter/services.dart';

import 'package:bamm/core/errors/app_exceptions.dart';
import 'package:bamm/core/logging/app_logger.dart';
import 'package:bamm/features/shizuku/domain/shizuku_bridge.dart';

/// [ShizukuBridge] implementation backed by a platform [MethodChannel].
class MethodChannelShizukuBridge implements ShizukuBridge {
  MethodChannelShizukuBridge() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static const _channel = MethodChannel('com.example.bamm/shizuku');
  static const _tag = 'ShizukuBridge';

  final _binderReceivedController = StreamController<void>.broadcast();
  final _binderDeadController = StreamController<void>.broadcast();

  // ---------------------------------------------------------------------------
  // Native → Flutter event handler
  // ---------------------------------------------------------------------------

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onBinderReceived':
        AppLogger.info('Binder received', tag: _tag);
        _binderReceivedController.add(null);
      case 'onBinderDead':
        AppLogger.warning('Binder dead', tag: _tag);
        _binderDeadController.add(null);
    }
  }

  // ---------------------------------------------------------------------------
  // Shizuku lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<bool> pingBinder() => _invokeBool('pingBinder');

  @override
  Future<bool> checkPermission() => _invokeBool('checkPermission');

  @override
  Future<bool> requestPermission() => _invokeBool('requestPermission');

  @override
  Future<int> getVersion() async {
    try {
      final version = await _channel.invokeMethod<int>('getVersion');
      return version ?? -1;
    } on PlatformException catch (e, st) {
      _logPlatformError('getVersion', e, st);
      throw const ShizukuNotAvailableException(
        'Failed to get Shizuku version',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // UserService lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<bool> bindService() => _invokeBool('bindService');

  @override
  Future<bool> unbindService() => _invokeBool('unbindService');

  @override
  Future<bool> isServiceBound() => _invokeBool('isServiceBound');

  // ---------------------------------------------------------------------------
  // File operations
  // ---------------------------------------------------------------------------

  @override
  Future<bool> fileExists(String path) =>
      _invokeBool('fileExists', {'path': path});

  @override
  Future<List<int>?> readFile(String path) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'readFile',
        {'path': path},
      );
      return result;
    } on PlatformException catch (e, st) {
      _logPlatformError('readFile', e, st);
      return null;
    }
  }

  @override
  Future<bool> writeFile(String path, List<int> data) => _invokeBool(
    'writeFile',
    {'path': path, 'data': Uint8List.fromList(data)},
  );

  @override
  Future<bool> copyFile(String source, String dest) => _invokeBool(
    'copyFile',
    {'source': source, 'dest': dest},
  );

  @override
  Future<bool> deleteFile(String path) =>
      _invokeBool('deleteFile', {'path': path});

  @override
  Future<List<String>> listFiles(String directoryPath) async {
    try {
      final result = await _channel.invokeListMethod<String>(
        'listFiles',
        {'path': directoryPath},
      );
      return result ?? [];
    } on PlatformException catch (e, st) {
      _logPlatformError('listFiles', e, st);
      return [];
    }
  }

  @override
  Future<List<String>> listFilesPage(
    String directoryPath,
    int offset,
    int limit,
  ) async {
    try {
      final result = await _channel.invokeListMethod<String>('listFilesPage', {
        'path': directoryPath,
        'offset': offset,
        'limit': limit,
      });
      return result ?? [];
    } on PlatformException catch (e, st) {
      _logPlatformError('listFilesPage', e, st);
      return [];
    }
  }

  @override
  Future<bool> createDirectory(String path) =>
      _invokeBool('createDirectory', {'path': path});

  @override
  Future<bool> isDirectory(String path) =>
      _invokeBool('isDirectory', {'path': path});

  @override
  Future<int> getFileSize(String path) async {
    try {
      final size = await _channel.invokeMethod<int>(
        'getFileSize',
        {'path': path},
      );
      return size ?? -1;
    } on PlatformException catch (e, st) {
      _logPlatformError('getFileSize', e, st);
      return -1;
    }
  }

  @override
  Future<String?> getFileMd5(String path) async {
    try {
      return await _channel.invokeMethod<String>('getFileMd5', {'path': path});
    } on PlatformException catch (e, st) {
      _logPlatformError('getFileMd5', e, st);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Package operations
  // ---------------------------------------------------------------------------

  @override
  Future<bool> isPackageInstalled(String packageName) =>
      _invokeBool('isPackageInstalled', {'packageName': packageName});

  @override
  Future<bool> launchPackage(String packageName) =>
      _invokeBool('launchPackage', {'packageName': packageName});

  @override
  Future<String?> getPackageVersionName(String packageName) async {
    try {
      return await _channel.invokeMethod<String>(
        'getPackageVersionName',
        {'packageName': packageName},
      );
    } on PlatformException catch (e, st) {
      _logPlatformError('getPackageVersionName', e, st);
      return null;
    }
  }

  @override
  Future<int> getPackageVersionCode(String packageName) async {
    try {
      final code = await _channel.invokeMethod<int>(
        'getPackageVersionCode',
        {'packageName': packageName},
      );
      return code ?? -1;
    } on PlatformException catch (e, st) {
      _logPlatformError('getPackageVersionCode', e, st);
      return -1;
    }
  }

  // ---------------------------------------------------------------------------
  // Event streams
  // ---------------------------------------------------------------------------

  @override
  Stream<void> get onBinderReceived => _binderReceivedController.stream;

  @override
  Stream<void> get onBinderDead => _binderDeadController.stream;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<bool> _invokeBool(String method, [Map<String, dynamic>? args]) async {
    try {
      final result = await _channel.invokeMethod<bool>(method, args);
      return result ?? false;
    } on PlatformException catch (e, st) {
      _logPlatformError(method, e, st);
      return false;
    }
  }

  void _logPlatformError(
    String method,
    PlatformException e,
    StackTrace st,
  ) {
    AppLogger.error(
      'MethodChannel call "$method" failed: ${e.message}',
      tag: _tag,
      error: e,
      stackTrace: st,
    );
  }
}
