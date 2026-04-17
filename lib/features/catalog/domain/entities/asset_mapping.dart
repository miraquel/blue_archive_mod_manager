/// Represents a mapping entry from CRC hash to a human-readable asset name.
///
/// Used to resolve game file CRC hashes back to their original asset names,
/// which is essential for identifying and managing mod targets.
class AssetMapping {
  final String crcHash;
  final String assetName;
  final String? bundleName;
  final int? fileSize;

  const AssetMapping({
    required this.crcHash,
    required this.assetName,
    this.bundleName,
    this.fileSize,
  });

  factory AssetMapping.fromJson(Map<String, dynamic> json) {
    return AssetMapping(
      crcHash: json['crcHash'] as String,
      assetName: json['assetName'] as String,
      bundleName: json['bundleName'] as String?,
      fileSize: json['fileSize'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'crcHash': crcHash,
        'assetName': assetName,
        if (bundleName != null) 'bundleName': bundleName,
        if (fileSize != null) 'fileSize': fileSize,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetMapping &&
          runtimeType == other.runtimeType &&
          crcHash == other.crcHash &&
          assetName == other.assetName &&
          bundleName == other.bundleName &&
          fileSize == other.fileSize;

  @override
  int get hashCode => Object.hash(crcHash, assetName, bundleName, fileSize);

  @override
  String toString() => 'AssetMapping(crc: $crcHash, name: $assetName)';
}
