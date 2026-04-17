import 'package:bamm/core/constants/app_constants.dart';

abstract class LauncherRepository {
  Future<bool> launchGame(GameRegion region);
  Future<bool> isGameInstalled(GameRegion region);
}
