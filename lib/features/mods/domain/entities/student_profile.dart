class StudentProfile {
  final String id;
  final String devName;
  final String nameEn;
  final String? nameTw;
  final String? nameCn;

  const StudentProfile({
    required this.id,
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
      'devName': devName,
      'nameEn': nameEn,
      'nameTw': nameTw,
      'nameCn': nameCn,
    };
  }

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] as String,
      devName: json['devName'] as String,
      nameEn: json['nameEn'] as String,
      nameTw: json['nameTw'] as String?,
      nameCn: json['nameCn'] as String?,
    );
  }
}
