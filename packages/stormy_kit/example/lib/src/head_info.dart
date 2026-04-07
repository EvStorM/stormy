import 'dart:io';

import 'package:example/config.dart';
import 'package:flutter/material.dart';
import 'package:stormy_kit/stormy_kit.dart';

// 默认语言
Locale defaultLocale = const Locale('en', 'US');

// 前端请求头配置 - 用于传递设备和应用信息
// ignore: constant_identifier_names
const REQUEST_HEADERS = {
  // 设备平台 (如: ios, android, web, h5)
  'X-Device-Platform': '',

  // 渠道编码 (qiaopai-ai-001)
  'X-Channel': '',

  // OAID - 移动安全联盟匿名设备标识符 (Android)
  'X-OAID': '',

  // IDFV - Identifier for Vendor (iOS设备标识符)
  'X-IDFV': '',

  // IDFA - Identifier for Advertisers (iOS广告标识符)
  'X-IDFA': '',

  // IMEI - International Mobile Equipment Identity (移动设备国际身份码)
  'X-IMEI': '',

  // Android ID - Android设备唯一标识符
  'X-Android-Id': '',

  // 应用版本号 (如: 1.0.0, 2.1.3)
  'X-App-Version': '',

  // 操作系统版本 (如: 14.5, 11.0, 13)
  'X-OS-Version': '',

  // 操作系统名称 (如: iOS, Android, Windows, macOS)
  'X-Os-Name': '',

  // 设备型号 (如: iPhone 12, Pixel 5, Huawei P40)
  'X-Device-Model': '',

  // 业务设备标识
  'X-Bddid': '',

  // 设备唯一标识 (用于数据埋点)
  'X-DistinctId': '',
};

class HeaderInfo {
  final String channel;
  final String osName;
  final String oaid;
  final String imei;
  final String androidId;
  final String idfa;
  final String idfv;
  final String osVersion;
  final String appVersion;
  final String deviceModel;
  final String bddid;
  final String distinctId;
  HeaderInfo({
    required this.channel,
    required this.osName,
    required this.oaid,
    required this.imei,
    required this.androidId,
    required this.idfa,
    required this.idfv,
    required this.osVersion,
    required this.appVersion,
    required this.deviceModel,
    this.bddid = '',
    this.distinctId = '',
  });

  factory HeaderInfo.fromJson(Map<String, dynamic> json) {
    return HeaderInfo(
      channel: json['channel'] ?? json['X-Channel'] ?? '',
      osName: json['osName'] ??
          json['X-Os-Name'] ??
          json['X-Device-Platform'] ??
          '',
      oaid: json['oaid'] ?? json['X-OAID'] ?? '',
      imei: json['imei'] ?? json['X-IMEI'] ?? '',
      androidId: json['androidId'] ?? json['X-Android-Id'] ?? '',
      idfa: json['idfa'] ?? json['X-IDFA'] ?? '',
      idfv: json['idfv'] ?? json['X-IDFV'] ?? '',
      osVersion: json['osVersion'] ?? json['X-OS-Version'] ?? '',
      appVersion: json['appVersion'] ?? json['X-App-Version'] ?? '',
      deviceModel: json['deviceModel'] ?? json['X-Device-Model'] ?? '',
      bddid: json['bddid'] ?? json['X-Bddid'] ?? '',
      distinctId: json['distinctId'] ?? json['X-DistinctId'] ?? '',
    );
  }

  @override
  String toString() {
    return 'HeaderInfo(channel: $channel, osName: $osName, oaid: $oaid, imei: $imei, androidId: $androidId, idfa: $idfa, idfv: $idfv, osVersion: $osVersion, appVersion: $appVersion, deviceModel: $deviceModel, bddid: $bddid, distinctId: $distinctId)';
  }

  Map<String, dynamic> toJson() {
    return {
      'X-Device-Platform': osName, // 使用osName作为设备平台
      'X-Channel': channel,
      'X-OAID': oaid,
      'X-IDFV': idfv,
      'X-IDFA': idfa,
      'X-IMEI': imei,
      'X-Android-Id': androidId,
      'X-App-Version': appVersion,
      'X-OS-Version': osVersion,
      'X-Os-Name': osName,
      'X-Device-Model': deviceModel,
      'X-Bddid': bddid,
      'X-DistinctId': distinctId,
    };
  }

  Map<String, dynamic> toThinkJson() {
    return {
      'X_Device_Platform': osName, // 使用osName作为设备平台
      'X_Channel': channel,
      'X_OAID': oaid,
      'X_IDFV': idfv,
      'X_IDFA': idfa,
      'X_IMEI': imei,
      'X_Android_Id': androidId,
      'X_App_Version': appVersion,
      'X_OS_Version': osVersion,
      'X_Os_Name': osName,
      'X_Device_Model': deviceModel,
      'X_Bddid': bddid,
      'X_DistinctId': distinctId,
    };
  }

  HeaderInfo copyWith({
    String? channel,
    String? osName,
    String? oaid,
    String? imei,
    String? androidId,
    String? idfa,
    String? idfv,
    String? osVersion,
    String? appVersion,
    String? deviceModel,
    String? bddid,
    String? distinctId,
  }) {
    return HeaderInfo(
      channel: channel ?? this.channel,
      osName: osName ?? this.osName,
      oaid: oaid ?? this.oaid,
      imei: imei ?? this.imei,
      androidId: androidId ?? this.androidId,
      idfa: idfa ?? this.idfa,
      idfv: idfv ?? this.idfv,
      osVersion: osVersion ?? this.osVersion,
      appVersion: appVersion ?? this.appVersion,
      deviceModel: deviceModel ?? this.deviceModel,
      bddid: bddid ?? this.bddid,
      distinctId: distinctId ?? this.distinctId,
    );
  }
}

/// 设置HeaderInfo
///
/// [context] 可选的上下文，用于获取语言设置。如果不提供，将使用默认语言或已存储的 locale
/// [maxRetries] 最大重试次数，默认3次
/// [retryDelay] 重试延迟（毫秒），默认300ms
///
/// WHY:
/// 1. 添加并发控制，防止重复执行
/// 2. 确保只有在成功获取 aid 后才标记为就绪，阻塞后续请求直到完成
/// 3. 改进重试机制，避免无限递归重试，添加最大重试次数限制
/// 4. 减少对 context 的依赖
/// 5. 优化：优先使用本地已有的 HeaderInfo，仅刷新基础信息，避免重复生成设备标识
Future<void> setHeaderInfo(
  BuildContext? context, {
  int maxRetries = 3,
  int retryDelay = 300,
}) async {
  // 先读取本地 HeaderInfo
  final current = getLocalHeaderInfo();

  // 如果本地还没有有效 HeaderInfo，则走原有的初始化流程（包含重试 & 并发控制）
  if (current == null) {
    final headInfo = await initHeaderInfo();
    applyHeaderInfo(headInfo);
    return;
  }

  // 已有本地 HeaderInfo 时，仅获取最新的基础信息并合并更新
  Locale? locale;
  if (context != null) {
    final currentLocale = Localizations.maybeLocaleOf(context);
    if (currentLocale != null) {
      locale = currentLocale;
    }
  }
  final basic = await buildBasic(locale);

  final updatedHeaderInfo = HeaderInfo(
    channel: basic.channel,
    osName: basic.osName,
    imei: current.imei,
    oaid: current.oaid,
    androidId: current.androidId,
    idfa: current.idfa,
    idfv: current.idfv,
    osVersion: basic.osVersion,
    appVersion: basic.appVersion,
    deviceModel: current.deviceModel,
    bddid: current.bddid,
    distinctId: current.distinctId,
  );
  applyHeaderInfo(updatedHeaderInfo, notifyReady: false);
}

Future<HeaderInfo> initHeaderInfo() async {
  final aid = await AppUtils.getDeviceUniqueId();
  if (aid == null) {
    await Future.delayed(const Duration(milliseconds: 300));
    return await initHeaderInfo();
  } else {
    final imei = "";
    final androidId = await AppUtils.getAndroidId() ?? aid;
    final osName = !Platform.isAndroid ? "android" : "ios";
    String idfv;
    String idfa;
    try {
      idfv = await AppUtils.getAppleIDFV() ?? '';
      idfa = await AppUtils.getIosIDFAId() ?? '';
    } catch (e) {
      idfv = "";
      idfa = "";
    }
    final osVersion = await AppUtils.getSystemVersion();
    final appVersion = await AppUtils.getVersionNumber();
    final deviceModel = await AppUtils.getDeviceModel();
    final headerInfo = HeaderInfo(
      channel: ProjectConfig.channelCode,
      osName: osName,
      imei: imei,
      oaid: aid,
      androidId: androidId,
      idfa: idfa,
      idfv: idfv,
      osVersion: osVersion,
      appVersion: appVersion,
      deviceModel: deviceModel,
      bddid: '',
      distinctId: '',
    );
    return headerInfo;
  }
}

String headerInfoKey = 'HEADERINFO';

HeaderInfo? getLocalHeaderInfo() {
  final Map<String, dynamic> headerInfo =
      StormyStorage.instance.getJson(headerInfoKey) ?? {};
  try {
    if (headerInfo.isNotEmpty) {
      return HeaderInfo.fromJson(headerInfo);
    }
    return null;
  } catch (e) {
    rethrow;
  }
}

Future<void> setLocalHeaderInfo(HeaderInfo value) async {
  await StormyStorage.instance.setJson(headerInfoKey, value.toJson());
}

/// 构建基础 HeaderInfo，不依赖设备唯一 ID
Future<HeaderInfo> buildBasic(Locale? locale) async {
  final osName = Platform.isAndroid ? "android" : "ios";
  final osVersion = await AppUtils.getSystemVersion();
  final appVersion = await AppUtils.getVersionNumber();

  return HeaderInfo(
    channel: ProjectConfig.channelCode,
    osName: osName,
    imei: "",
    oaid: "",
    androidId: "",
    idfa: "",
    idfv: "",
    osVersion: osVersion,
    appVersion: appVersion,
    deviceModel: "",
    bddid: "",
    distinctId: "",
  );
}

void applyHeaderInfo(HeaderInfo headerInfo, {bool notifyReady = true}) {
  setLocalHeaderInfo(headerInfo);
  StormyConfigAccessor.networkClient?.completeGlobalHeader(headerInfo.toJson());
}
