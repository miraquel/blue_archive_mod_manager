import 'package:bamm/features/mods/domain/entities/mod_entry.dart';

abstract class ModRepository {
  Future<List<ModEntry>> getAllMods();
  Future<ModEntry?> getModById(String id);
  Future<void> saveMod(ModEntry mod);
  Future<void> deleteMod(String id);
  Future<void> updateMod(ModEntry mod);
}
