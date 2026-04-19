/// A single resource entry from the official Nexon version manifest.
class ManifestResource {
  final String group;
  final String resourcePath;
  final int resourceSize;
  final String resourceHash;

  const ManifestResource({
    required this.group,
    required this.resourcePath,
    required this.resourceSize,
    required this.resourceHash,
  });

  /// The file name (last path segment) of [resourcePath].
  String get fileName {
    final lastSlash = resourcePath.lastIndexOf('/');
    return lastSlash < 0 ? resourcePath : resourcePath.substring(lastSlash + 1);
  }

  factory ManifestResource.fromJson(Map<String, dynamic> json) {
    return ManifestResource(
      group: json['group'] as String? ?? '',
      resourcePath: json['resource_path'] as String,
      resourceSize: json['resource_size'] as int,
      resourceHash: json['resource_hash'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'group': group,
        'resource_path': resourcePath,
        'resource_size': resourceSize,
        'resource_hash': resourceHash,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManifestResource &&
          runtimeType == other.runtimeType &&
          resourcePath == other.resourcePath;

  @override
  int get hashCode => resourcePath.hashCode;

  @override
  String toString() =>
      'ManifestResource(path: $resourcePath, size: $resourceSize)';
}
