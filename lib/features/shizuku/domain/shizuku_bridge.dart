/// Abstract interface for the Shizuku native bridge.
///
/// Defines all operations available through Shizuku's privileged access,
/// including lifecycle management, file operations, and package operations.
abstract class ShizukuBridge {
  // ---------------------------------------------------------------------------
  // Shizuku lifecycle
  // ---------------------------------------------------------------------------

  /// Check if the Shizuku binder is alive.
  Future<bool> pingBinder();

  /// Check whether this app already has Shizuku permission.
  Future<bool> checkPermission();

  /// Request Shizuku permission from the user.
  Future<bool> requestPermission();

  /// Get the Shizuku server version.
  Future<int> getVersion();

  // ---------------------------------------------------------------------------
  // UserService lifecycle
  // ---------------------------------------------------------------------------

  /// Bind to the privileged UserService.
  Future<bool> bindService();

  /// Unbind from the privileged UserService.
  Future<bool> unbindService();

  /// Check if the UserService is currently bound.
  Future<bool> isServiceBound();

  // ---------------------------------------------------------------------------
  // File operations (privileged)
  // ---------------------------------------------------------------------------

  /// Check if a file exists at [path].
  Future<bool> fileExists(String path);

  /// Read all bytes from [path]. Returns `null` if the file cannot be read.
  Future<List<int>?> readFile(String path);

  /// Write [data] bytes to [path].
  Future<bool> writeFile(String path, List<int> data);

  /// Copy a file from [source] to [dest].
  Future<bool> copyFile(String source, String dest);

  /// Delete the file at [path].
  Future<bool> deleteFile(String path);

  /// List files in [directoryPath].
  Future<List<String>> listFiles(String directoryPath);

  /// Create a directory at [path].
  Future<bool> createDirectory(String path);

  /// Check if [path] is a directory.
  Future<bool> isDirectory(String path);

  /// Get the size in bytes of the file at [path].
  Future<int> getFileSize(String path);

  // ---------------------------------------------------------------------------
  // Package operations
  // ---------------------------------------------------------------------------

  /// Check if [packageName] is installed on the device.
  Future<bool> isPackageInstalled(String packageName);

  /// Launch the app identified by [packageName].
  Future<bool> launchPackage(String packageName);

  // ---------------------------------------------------------------------------
  // Event streams (native → Flutter)
  // ---------------------------------------------------------------------------

  /// Fires when the Shizuku binder becomes available.
  Stream<void> get onBinderReceived;

  /// Fires when the Shizuku binder dies.
  Stream<void> get onBinderDead;
}
