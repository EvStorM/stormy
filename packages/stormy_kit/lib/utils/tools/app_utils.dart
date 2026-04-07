import 'dart:io';

import 'package:device_identifier_plugin/device_identifier_plugin.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'log_utils.dart';
import 'package:device_info_plus/device_info_plus.dart' as DeviceInfoPlugin;

class AppUtils {
  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();
  static const IOSOptions _iosSecureOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );
  static const String _iosDeviceIdKey = 'home_ai_ios_device_id';
  static const Uuid _uuid = Uuid();

  /// App名称
  static Future<String> getAppName() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.appName;
    } catch (e, stackTrace) {
      StormyLog.e(
        'AppUtils.getAppName: 获取App名称失败',
        stackTrace: stackTrace,
        extra: {'error': e.toString()},
      );
      return '';
    }
  }

  /// 包名
  static Future<String> getPackageName() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.packageName;
    } catch (e, stackTrace) {
      StormyLog.e(
        'AppUtils.getPackageName: 获取包名失败',
        stackTrace: stackTrace,
        extra: {'error': e.toString()},
      );
      return '';
    }
  }

  // 系统版本号
  static Future<String> getSystemVersion() async {
    try {
      if (Platform.isAndroid) {
        DeviceInfoPlugin.AndroidDeviceInfo androidInfo =
            await deviceInfoPlugin.androidInfo;
        return androidInfo.version.release;
      }
      if (Platform.isIOS) {
        DeviceInfoPlugin.IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
        return iosInfo.systemVersion;
      }
      return '';
    } catch (e, stackTrace) {
      StormyLog.e(
        'AppUtils.getSystemVersion: 获取系统版本号失败',
        stackTrace: stackTrace,
        extra: {'error': e.toString()},
      );
      return '';
    }
  }

  /// 版本名
  static Future<String> getVersionName() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e, stackTrace) {
      StormyLog.e(
        'AppUtils.getVersionName: 获取版本名失败',
        stackTrace: stackTrace,
        extra: {'error': e.toString()},
      );
      return '';
    }
  }

  /// 版本号
  static Future<String> getVersionNumber() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.buildNumber;
    } catch (e, stackTrace) {
      StormyLog.e(
        'AppUtils.getVersionNumber: 获取版本号失败',
        stackTrace: stackTrace,
        extra: {'error': e.toString()},
      );
      return '';
    }
  }

  /// 获取App构建签名
  /// 在 iOS 上为空字符串，在 Android 上为密钥签名(十六进制)
  static Future<String> getBuildSignature() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.buildSignature;
    } catch (e, stackTrace) {
      StormyLog.e(
        'AppUtils.getBuildSignature: 获取构建签名失败',
        stackTrace: stackTrace,
        extra: {'error': e.toString()},
      );
      return '';
    }
  }

  /// 获取App安装商店
  /// 若是通过应用商店安装的应用，返回应用商店的名称，否则返回空字符串
  static Future<String> getInstallerStore() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.installerStore ?? '';
    } catch (e, stackTrace) {
      StormyLog.e(
        'AppUtils.getInstallerStore: 获取安装商店失败',
        stackTrace: stackTrace,
        extra: {'error': e.toString()},
      );
      return '';
    }
  }

  static final deviceInfoPlugin = DeviceInfoPlugin.DeviceInfoPlugin();

  static final deviceIdentifier = DeviceIdentifierPlugin.instance;

  /// 获取 AndroidId
  static Future<String?> getBaseDeviceId() async {
    try {
      String? deviceId = await deviceIdentifier.getBestDeviceIdentifier();
      // 根据 AndroidId 生成 UUID
      if (deviceId != null && deviceId.isNotEmpty) {
        return deviceId;
      }
      return null;
    } catch (e, stackTrace) {
      StormyLog.e(
        'AppUtils.getBaseDeviceId: 获取BaseDeviceId失败',
        stackTrace: stackTrace,
        extra: {'error': e.toString()},
      );
      return null;
    }
  }

  /// 获取 AndroidId
  static Future<String?> getAndroidId() async {
    if (!Platform.isAndroid) return null;
    try {
      String? androidId = await deviceIdentifier.getAndroidId();
      if ("9774d56d682e549c" == androidId) return null;
      // 根据 AndroidId 生成 UUID
      if (androidId != null && androidId.isNotEmpty) {
        return androidId;
      }
      return null;
    } catch (e, stackTrace) {
      StormyLog.e(
        'AppUtils.getAndroidId: 获取AndroidId失败',
        stackTrace: stackTrace,
        extra: {'error': e.toString()},
      );
      return null;
    }
  }

  /// 获取adID(区分安卓和iOS)
  static Future<String?> getAdId() async {
    try {
      if (Platform.isAndroid) {
        String? adId = await deviceIdentifier.getAdvertisingIdForAndroid();
        return adId;
      }
      if (Platform.isIOS) {
        String? adId = await deviceIdentifier.getAdvertisingIdForiOS();
        return adId;
      }
      return null;
    } catch (e, stackTrace) {
      StormyLog.e(
        'AppUtils.getAdId: 获取AdId失败',
        stackTrace: stackTrace,
        extra: {'error': e.toString()},
      );
      return null;
    }
  }

  /// 获取 iOS 唯一标识
  /// 优先读取 KeyChain 缓存，失败时依次尝试 IDFA、IDFV，最后生成本地 UUID 保存
  static Future<String?> getIosUniqueId() async {
    if (!Platform.isIOS) return null;

    final cachedId = await _readIosDeviceIdFromKeychain();
    if (_isValidIdentifier(cachedId)) {
      return cachedId;
    }
    final generatedId = _uuid.v4();
    await _writeIosDeviceIdToKeychain(generatedId);
    return generatedId;
    // final idfa = await deviceIdentifier.getAdvertisingIdForiOS();
    // if (_isValidIdentifier(idfa)) {
    //   await _writeIosDeviceIdToKeychain(idfa!);
    //   return idfa;
    // }

    // final idfv = await deviceIdentifier.getAppleIDFV();
    // if (_isValidIdentifier(idfv)) {
    //   await _writeIosDeviceIdToKeychain(idfv!);
    //   return idfv;
    // }
  }

  /// 获取iOS IDFA
  static Future<String?> getIosIDFAId() async {
    final staus = await deviceIdentifier.requestTrackingAuthorization();
    if (staus == 'denied') {
      return null;
    } else {
      String? iosId = await deviceIdentifier.getAdvertisingIdForiOS();
      return iosId;
    }
  }

  /// 获取iOS IDFV
  static Future<String?> getAppleIDFV() async {
    String? iosIdfa = await deviceIdentifier.getAppleIDFV();
    return iosIdfa;
  }

  /// 获取设备唯一标识(AndroidId或iOS唯一标识)
  ///
  /// WHY: 改进iOS设备ID获取，增加重试机制和临时ID机制
  /// 解决iOS首次启动时Keychain未解锁导致设备ID获取失败的问题
  static Future<String?> getDeviceUniqueId() async {
    // 先判断是否是Android
    if (Platform.isAndroid) {
      String? androidId = await getAndroidId();
      if (androidId != null && androidId.isNotEmpty) {
        return androidId;
      }
    }
    // 再判断是否是iOS
    if (Platform.isIOS) {
      // 增加重试机制，等待Keychain解锁
      // WHY: iOS首次启动时Keychain可能未解锁，需要多次重试
      // 增加重试次数和延迟时间，提高成功率
      for (int i = 0; i < 5; i++) {
        String? iosId = await getIosUniqueId();
        if (iosId != null && iosId.isNotEmpty) {
          return iosId;
        }
        // 等待Keychain解锁，递增延迟（100ms, 200ms, 300ms, 500ms）
        if (i < 4) {
          final delayMs = i == 0 ? 100 : (i == 1 ? 200 : (i == 2 ? 300 : 500));
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
      // 如果仍然失败，生成临时ID并异步保存到Keychain
      // 这样不会阻塞当前请求，后续可以更新为持久ID
      final tempId = _uuid.v4();
      // 异步保存到Keychain（不阻塞）
      _writeIosDeviceIdToKeychain(tempId).catchError((_) {
        // 保存失败不影响当前流程
      });
      return tempId;
    }
    return null;
  }

  static bool _isValidIdentifier(String? value) {
    return value != null && value.isNotEmpty && value != '-1';
  }

  static Future<String?> _readIosDeviceIdFromKeychain() async {
    try {
      return await _secureStorage.read(
        key: _iosDeviceIdKey,
        iOptions: _iosSecureOptions,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeIosDeviceIdToKeychain(String value) async {
    try {
      await _secureStorage.write(
        key: _iosDeviceIdKey,
        value: value,
        iOptions: _iosSecureOptions,
      );
    } catch (_) {
      // 写入失败时不抛出，避免影响后续逻辑
    }
  }

  /// 获取设备型号
  /// 返回如 "iPhone 12, Pixel 5, Huawei P40" 这样的字符串
  static Future<String> getDeviceModel() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        return androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        return iosInfo.utsname.machine;
      } else {
        return 'Unknown Device';
      }
    } catch (e, stackTrace) {
      StormyLog.e(
        'AppUtils.getDeviceModel: 获取设备型号失败',
        stackTrace: stackTrace,
        extra: {'error': e.toString()},
      );
      return 'Unknown Device';
    }
  }

  // 获取设备品牌
  static Future<String> getDeviceBrand() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        return androidInfo.brand;
      }
    } catch (e, stackTrace) {
      StormyLog.e(
        'AppUtils.getDeviceBrand: 获取设备品牌失败',
        stackTrace: stackTrace,
        extra: {'error': e.toString()},
      );
      return 'Unknown Brand';
    }
    return 'Unknown Brand';
  }
}
