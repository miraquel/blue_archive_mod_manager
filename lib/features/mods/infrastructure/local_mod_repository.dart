import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:bamm/features/mods/domain/entities/mod_entry.dart';
import 'package:bamm/features/mods/domain/repositories/mod_repository.dart';

class LocalModRepository implements ModRepository {
  final SharedPreferences _prefs;
  static const _modsKey = 'mod_entries';

  LocalModRepository(this._prefs);

  @override
  Future<List<ModEntry>> getAllMods() async {
    final jsonString = _prefs.getString(_modsKey);
    if (jsonString == null || jsonString.isEmpty) return [];

    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
    return jsonList
        .map((e) => ModEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ModEntry?> getModById(String id) async {
    final mods = await getAllMods();
    try {
      return mods.firstWhere((m) => m.id == id);
    } on StateError {
      return null;
    }
  }

  @override
  Future<void> saveMod(ModEntry mod) async {
    final mods = await getAllMods();
    mods.add(mod);
    await _persist(mods);
  }

  @override
  Future<void> deleteMod(String id) async {
    final mods = await getAllMods();
    mods.removeWhere((m) => m.id == id);
    await _persist(mods);
  }

  @override
  Future<void> updateMod(ModEntry mod) async {
    final mods = await getAllMods();
    final index = mods.indexWhere((m) => m.id == mod.id);
    if (index == -1) {
      throw StateError('Mod with id ${mod.id} not found');
    }
    mods[index] = mod;
    await _persist(mods);
  }

  Future<void> _persist(List<ModEntry> mods) async {
    final jsonString = json.encode(mods.map((m) => m.toJson()).toList());
    await _prefs.setString(_modsKey, jsonString);
  }
}
