/// Progression of the Shizuku connection, ordered from least to most ready.
enum ShizukuStatus {
  unknown,
  notInstalled,
  installed,
  binderAlive,
  permissionGranted,
  serviceBound,
}

/// Immutable snapshot of the current Shizuku connection state.
class ShizukuState {
  const ShizukuState({
    this.status = ShizukuStatus.unknown,
    this.version,
    this.errorMessage,
    this.isLoading = false,
  });

  final ShizukuStatus status;
  final int? version;
  final String? errorMessage;
  final bool isLoading;

  /// Whether the full privileged pipeline is ready (service is bound).
  bool get isReady => status == ShizukuStatus.serviceBound;

  /// Whether at least Shizuku permission has been granted.
  bool get hasPermission =>
      status.index >= ShizukuStatus.permissionGranted.index;

  ShizukuState copyWith({
    ShizukuStatus? status,
    int? version,
    String? errorMessage,
    bool? isLoading,
  }) {
    return ShizukuState(
      status: status ?? this.status,
      version: version ?? this.version,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShizukuState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          version == other.version &&
          errorMessage == other.errorMessage &&
          isLoading == other.isLoading;

  @override
  int get hashCode => Object.hash(status, version, errorMessage, isLoading);

  @override
  String toString() =>
      'ShizukuState(status: $status, version: $version, '
      'errorMessage: $errorMessage, isLoading: $isLoading)';
}
