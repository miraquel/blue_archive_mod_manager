import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:bamm/features/mods/domain/entities/global_android_asset_index.dart';

class BundledGlobalAndroidAssetIndexLoader {
  static const assetPath = 'assets/data/global_android_asset_index.json';

  const BundledGlobalAndroidAssetIndexLoader();

  Future<GlobalAndroidAssetIndex> load() async {
    final rawJson = await rootBundle.loadString(assetPath);
    final decoded = json.decode(rawJson) as Map<String, dynamic>;
    return GlobalAndroidAssetIndex.fromJson(decoded);
  }
}
