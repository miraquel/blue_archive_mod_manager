import 'package:bamm/core/constants/app_constants.dart';
import 'package:bamm/features/launch/domain/launcher_repository.dart';
import 'package:bamm/features/shizuku/domain/shizuku_bridge.dart';

class AndroidLauncherRepository implements LauncherRepository {
  final ShizukuBridge _bridge;

  AndroidLauncherRepository(this._bridge);

  @override
  Future<bool> launchGame(GameRegion region) async {
    return _bridge.launchPackage(region.packageId);
  }

  @override
  Future<bool> isGameInstalled(GameRegion region) async {
    return _bridge.isPackageInstalled(region.packageId);
  }
}
