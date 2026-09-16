import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:permission_handler/permission_handler.dart';

/// Native operations without UI prompts.
class StormyPlatform {
  StormyPlatform._();
  static Future<void> setHighRefreshRate() =>
      FlutterDisplayMode.setHighRefreshRate();
  static Future<PermissionStatus> requestPermission(Permission permission) =>
      permission.request();
}
