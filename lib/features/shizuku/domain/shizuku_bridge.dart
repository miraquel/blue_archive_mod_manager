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

  /// List a single page of child names in [directoryPath].
  ///
  /// The returned strings are entry names, not absolute paths.
  Future<List<String>> listFilesPage(String directoryPath, int offset, int limit);

  /// Create a directory at [path].
  Future<bool> createDirectory(String path);

  /// Check if [path] is a directory.
  Future<bool> isDirectory(String path);

  /// Get the size in bytes of the file at [path].
  Future<int> getFileSize(String path);

  /// Compute the MD5 hash of the file at [path].
  ///
  /// Returns `null` if the hash cannot be computed.
  Future<String?> getFileMd5(String path);

  // ---------------------------------------------------------------------------
  // Package operations
  // ---------------------------------------------------------------------------

  /// Check if [packageName] is installed on the device.
  Future<bool> isPackageInstalled(String packageName);

  /// Launch the app identified by [packageName].
  Future<bool> launchPackage(String packageName);

  /// Get the installed version code (Play Store build number) for [packageName].
  /// Returns -1 if the package is not installed.
  Future<int> getPackageVersionCode(String packageName);

  /// Get the installed version name string (e.g. "1.71.417475") for [packageName].
  /// Returns null if the package is not installed.
  Future<String?> getPackageVersionName(String packageName);

  // ---------------------------------------------------------------------------
  // Event streams (native → Flutter)
  // ---------------------------------------------------------------------------

  /// Fires when the Shizuku binder becomes available.
  Stream<void> get onBinderReceived;

  /// Fires when the Shizuku binder dies.
  Stream<void> get onBinderDead;
}
