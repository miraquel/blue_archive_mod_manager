class StudentProfile {
  final String id;
  /// Lowercase asset-path identifier from SchaleDB (e.g. `aru_newyear`).
  /// Matches the prefix used in game bundle filenames directly.
  final String? pathName;
  final String devName;
  final String nameEn;
  final String? nameTw;
  final String? nameCn;

  const StudentProfile({
    required this.id,
    this.pathName,
    required this.devName,
    required this.nameEn,
    this.nameTw,
    this.nameCn,
  });

  String get displayName => nameEn.isNotEmpty ? nameEn : devName;

  Iterable<String> get localizedNames sync* {
    yield nameEn;
    if (nameTw != null && nameTw!.isNotEmpty) {
      yield nameTw!;
    }
    if (nameCn != null && nameCn!.isNotEmpty) {
      yield nameCn!;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pathName': pathName,
      'devName': devName,
      'nameEn': nameEn,
      'nameTw': nameTw,
      'nameCn': nameCn,
    };
  }

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] as String,
      pathName: json['pathName'] as String?,
      devName: json['devName'] as String,
      nameEn: json['nameEn'] as String,
      nameTw: json['nameTw'] as String?,
      nameCn: json['nameCn'] as String?,
    );
  }
}
