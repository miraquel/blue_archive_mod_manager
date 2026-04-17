class GlobalAndroidAssetIndex {
  final Set<String> exactFiles;
  final Set<String> familyKeys;
  final Set<String> chunkGroupIds;

  const GlobalAndroidAssetIndex({
    required this.exactFiles,
    required this.familyKeys,
    required this.chunkGroupIds,
  });

  factory GlobalAndroidAssetIndex.fromJson(Map<String, dynamic> json) {
    Set<String> normalizeSet(String key) {
      final values = json[key] as List<dynamic>? ?? const [];
      return values
          .whereType<String>()
          .map((value) => value.toLowerCase())
          .toSet();
    }

    return GlobalAndroidAssetIndex(
      exactFiles: normalizeSet('exactFiles'),
      familyKeys: normalizeSet('familyKeys'),
      chunkGroupIds: normalizeSet('chunkGroupIds'),
    );
  }

  Map<String, dynamic> toJson() {
    List<String> sortValues(Set<String> values) {
      final sorted = values.toList()..sort();
      return sorted;
    }

    return {
      'exactFiles': sortValues(exactFiles),
      'familyKeys': sortValues(familyKeys),
      'chunkGroupIds': sortValues(chunkGroupIds),
    };
  }
}
