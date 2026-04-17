import 'package:bamm/core/constants/app_constants.dart';
import 'package:bamm/features/game_data/domain/entities/game_install.dart';

/// Immutable snapshot of detected game installations.
class GameInstallState {
  const GameInstallState({
    this.installations = const [],
    this.selectedRegion,
  });

  final List<GameInstall> installations;
  final GameRegion? selectedRegion;

  /// The [GameInstall] matching [selectedRegion], or `null` if none selected.
  GameInstall? get selectedInstall {
    if (selectedRegion == null) return null;
    final matches =
        installations.where((i) => i.region == selectedRegion);
    return matches.isEmpty ? null : matches.first;
  }

  GameInstallState copyWith({
    List<GameInstall>? installations,
    GameRegion? selectedRegion,
    bool clearSelectedRegion = false,
  }) {
    return GameInstallState(
      installations: installations ?? this.installations,
      selectedRegion:
          clearSelectedRegion ? null : (selectedRegion ?? this.selectedRegion),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameInstallState &&
          runtimeType == other.runtimeType &&
          installations.length == other.installations.length &&
          selectedRegion == other.selectedRegion &&
          _listEquals(installations, other.installations);

  static bool _listEquals(List<GameInstall> a, List<GameInstall> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(installations),
        selectedRegion,
      );

  @override
  String toString() =>
      'GameInstallState(installations: ${installations.length}, '
      'selectedRegion: $selectedRegion)';
}
