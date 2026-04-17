enum ModAssetCategory {
  character,
  skill,
  ui,
  audio,
  effect,
  environment,
  shared,
  unknown,
}

extension ModAssetCategoryX on ModAssetCategory {
  String get label {
    switch (this) {
      case ModAssetCategory.character:
        return 'Character';
      case ModAssetCategory.skill:
        return 'Skill';
      case ModAssetCategory.ui:
        return 'UI';
      case ModAssetCategory.audio:
        return 'Audio';
      case ModAssetCategory.effect:
        return 'Effect';
      case ModAssetCategory.environment:
        return 'Environment';
      case ModAssetCategory.shared:
        return 'Shared';
      case ModAssetCategory.unknown:
        return 'Unknown';
    }
  }
}
