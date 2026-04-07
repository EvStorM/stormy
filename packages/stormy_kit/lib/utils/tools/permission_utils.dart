import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../stormy_kit.dart';

class PermissonTips {
  PermissonTips({
    required this.title,
    required this.content,
    required this.confirmText,
    required this.deniedText,
    required this.permanentlyDeniedText,
  });
  final String? title;
  final String? content;
  final String? confirmText;
  final String? deniedText;
  final String? permanentlyDeniedText;
}

class PermissionUtils {
  static Future<bool> getBase(
    BuildContext context,
    Permission permission,
    PermissonTips info,
  ) async {
    try {
      final status = await permission.status;
      if (status.isGranted) {
        return true;
      }
      if (status.isDenied && context.mounted) {
        final result = await StormyDialog.instance.showAlert(
          title: info.title,
          message: info.content ?? '',
          overrideConfig: StormyDialogUIConfig(confirmText: info.confirmText),
          position: StormyDialogPosition.center,
        );
        if (result == true) {
          await permission
              .onDeniedCallback(() async {
                // await openAppSettings();
              })
              .onPermanentlyDeniedCallback(() async {
                SmartDialog.showToast(
                  info.permanentlyDeniedText ?? '权限被永久拒绝，请到设置页面手动开启',
                );
              })
              .onGrantedCallback(() {})
              .onLimitedCallback(() {})
              .request();
          return await permission.status.isGranted;
        } else {
          SmartDialog.showToast(info.deniedText ?? '');
          return false;
        }
      }

      if (status.isPermanentlyDenied) {
        SmartDialog.showToast(
          info.permanentlyDeniedText ?? '权限被永久拒绝，请到设置页面手动开启',
        );
        return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // 获取授权
  static Future<bool> getPhoto(BuildContext context) async {
    return await getBase(
      context,
      Permission.photos,
      PermissonTips(
        title: "授权相册权限",
        content: "请先授权相册权限，否则会影响照片/视频保存",
        confirmText: "去授权",
        deniedText: "请授权相册权限，否则会影响照片/视频保存",
        permanentlyDeniedText: "相册权限被永久拒绝，请到设置页面手动开启",
      ),
    );
  }

  // 获取授权
  static Future<bool> getCamera(BuildContext context) async {
    return await getBase(
      context,
      Permission.camera,
      PermissonTips(
        title: "授权相机权限",
        content: "请先授权相机权限，否则会影响使用相机拍照",
        confirmText: "去授权",
        deniedText: "请授权相机权限，否则会影响使用相机拍照",
        permanentlyDeniedText: "相机权限被永久拒绝，请到设置页面手动开启",
      ),
    );
  }
}
