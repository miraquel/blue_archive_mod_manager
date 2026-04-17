import 'package:bamm/features/mods/domain/entities/student_profile.dart';

abstract class StudentIndexRepository {
  Future<List<StudentProfile>> getProfiles({bool forceRefresh = false});
}
