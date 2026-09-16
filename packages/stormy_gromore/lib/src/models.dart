import 'package:flutter/foundation.dart';

/// App IDs should be created separately for Android and iOS in GroMore.
@immutable
final class GromoreAppIds {
  const GromoreAppIds({required this.android, required this.ios});

  final String android;
  final String ios;

  String forPlatform(TargetPlatform platform) {
    final String value = switch (platform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
          'stormy_gromore only supports Android and iOS.',
        ),
    };
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, 'appId', 'App ID must not be empty.');
    }
    return value;
  }
}

enum GromoreTheme {
  normal(0),
  dark(1);

  const GromoreTheme(this.nativeValue);
  final int nativeValue;
}

enum GromoreAdOrientation {
  vertical(0),
  horizontal(1);

  const GromoreAdOrientation(this.nativeValue);
  final int nativeValue;
}

/// Privacy-denying defaults are intentional. Enable a capability only after
/// obtaining the user's consent and completing the host app's privacy flow.
@immutable
final class GromorePrivacyConfig {
  const GromorePrivacyConfig({
    this.canUseLocation = false,
    this.canUsePhoneState = false,
    this.canUseWifiState = false,
    this.canUseWriteExternalStorage = false,
    this.canUseAndroidId = false,
    this.canUseOaid = false,
    this.canUseIdfa = false,
    this.canUseIdfv = false,
    this.canUseStorageSize = false,
    this.allowUploadDeviceInfo = false,
    this.canUseInstalledAppList = false,
    this.canUseRecordAudio = false,
    this.canUseSensors = false,
    this.canUseMessages = false,
    this.limitPersonalAds = true,
    this.limitProgrammaticAds = true,
    this.forbidCaid = true,
  });

  final bool canUseLocation;
  final bool canUsePhoneState;
  final bool canUseWifiState;
  final bool canUseWriteExternalStorage;
  final bool canUseAndroidId;
  final bool canUseOaid;
  final bool canUseIdfa;
  final bool canUseIdfv;
  final bool canUseStorageSize;
  final bool allowUploadDeviceInfo;
  final bool canUseInstalledAppList;
  final bool canUseRecordAudio;
  final bool canUseSensors;
  final bool canUseMessages;
  final bool limitPersonalAds;
  final bool limitProgrammaticAds;
  final bool forbidCaid;

  Map<String, Object> toMap() => <String, Object>{
        'canUseLocation': canUseLocation,
        'canUsePhoneState': canUsePhoneState,
        'canUseWifiState': canUseWifiState,
        'canUseWriteExternalStorage': canUseWriteExternalStorage,
        'canUseAndroidId': canUseAndroidId,
        'canUseOaid': canUseOaid,
        'canUseIdfa': canUseIdfa,
        'canUseIdfv': canUseIdfv,
        'canUseStorageSize': canUseStorageSize,
        'allowUploadDeviceInfo': allowUploadDeviceInfo,
        'canUseInstalledAppList': canUseInstalledAppList,
        'canUseRecordAudio': canUseRecordAudio,
        'canUseSensors': canUseSensors,
        'canUseMessages': canUseMessages,
        'limitPersonalAds': limitPersonalAds,
        'limitProgrammaticAds': limitProgrammaticAds,
        'forbidCaid': forbidCaid,
      };
}

@immutable
final class GromoreConfig {
  const GromoreConfig({
    required this.appIds,
    required this.appName,
    this.debug = false,
    this.useMediation = true,
    this.theme = GromoreTheme.normal,
    this.allowShowNotification = true,
    this.supportMultiProcess = false,
    this.isPaidApp,
    this.rewardCallbackRetention = const Duration(seconds: 6),
    this.privacy = const GromorePrivacyConfig(),
  });

  final GromoreAppIds appIds;
  final String appName;
  final bool debug;
  final bool useMediation;
  final GromoreTheme theme;
  final bool allowShowNotification;
  final bool supportMultiProcess;
  final bool? isPaidApp;

  /// How long native code keeps a closed rewarded ad associated with its
  /// request ID while waiting for a late reward callback.
  ///
  /// Keep this longer than the Dart-side reward callback grace period so the
  /// native bridge cannot release the request before Dart stops waiting.
  final Duration rewardCallbackRetention;
  final GromorePrivacyConfig privacy;

  Map<String, Object> toMap({TargetPlatform? platform}) {
    if (appName.trim().isEmpty) {
      throw ArgumentError.value(
        appName,
        'appName',
        'App name must not be empty.',
      );
    }
    final int rewardCallbackRetentionMs =
        rewardCallbackRetention.inMilliseconds;
    if (rewardCallbackRetentionMs < 1 ||
        rewardCallbackRetentionMs > 0x7fffffff) {
      throw ArgumentError.value(
        rewardCallbackRetention,
        'rewardCallbackRetention',
        'Must be positive and fit in a signed 32-bit millisecond value.',
      );
    }
    final Map<String, Object> value = <String, Object>{
      'appId': appIds.forPlatform(platform ?? defaultTargetPlatform),
      'appName': appName,
      'debug': debug,
      'useMediation': useMediation,
      'theme': theme.nativeValue,
      'allowShowNotification': allowShowNotification,
      'supportMultiProcess': supportMultiProcess,
      'rewardCallbackRetentionMs': rewardCallbackRetentionMs,
      'privacy': privacy.toMap(),
    };
    final bool? paid = isPaidApp;
    if (paid != null) {
      value['isPaidApp'] = paid;
    }
    return value;
  }
}

@immutable
final class GromoreSplashRequest {
  const GromoreSplashRequest({
    required this.slotId,
    this.timeout = const Duration(milliseconds: 3500),
    this.muted = true,
    this.volume = 1,
    this.preload = true,
    this.shakeButton = true,
    this.useSurfaceView = true,
    this.bidNotify = false,
    this.autoShow = true,
  });

  final String slotId;
  final Duration timeout;
  final bool muted;
  final double volume;
  final bool preload;
  final bool shakeButton;
  final bool useSurfaceView;
  final bool bidNotify;
  final bool autoShow;

  Map<String, Object> toMap() {
    _checkSlotId(slotId);
    if (timeout <= Duration.zero || timeout.inMilliseconds > 0x7fffffff) {
      throw ArgumentError.value(
        timeout,
        'timeout',
        'Must be positive and fit in a signed 32-bit millisecond value.',
      );
    }
    if (!volume.isFinite || volume < 0 || volume > 1) {
      throw ArgumentError.value(volume, 'volume', 'Must be between 0 and 1.');
    }
    return <String, Object>{
      'slotId': slotId,
      'timeoutMs': timeout.inMilliseconds,
      'muted': muted,
      'volume': volume,
      'preload': preload,
      'shakeButton': shakeButton,
      'useSurfaceView': useSurfaceView,
      'bidNotify': bidNotify,
      'autoShow': autoShow,
    };
  }
}

@immutable
final class GromoreRewardedRequest {
  const GromoreRewardedRequest({
    required this.slotId,
    this.muted = false,
    this.orientation = GromoreAdOrientation.vertical,
    this.useSurfaceView = true,
    this.bidNotify = false,
    this.userId,
    this.customData,
    this.rewardName,
    this.rewardAmount,
  });

  final String slotId;
  final bool muted;
  final GromoreAdOrientation orientation;
  final bool useSurfaceView;
  final bool bidNotify;
  final String? userId;
  final String? customData;
  final String? rewardName;
  final int? rewardAmount;

  Map<String, Object> toMap() {
    _checkSlotId(slotId);
    final int? amount = rewardAmount;
    if (amount != null && amount <= 0) {
      throw ArgumentError.value(amount, 'rewardAmount', 'Must be positive.');
    }
    return _withoutNullValues(<String, Object?>{
      'slotId': slotId,
      'muted': muted,
      'orientation': orientation.nativeValue,
      'useSurfaceView': useSurfaceView,
      'bidNotify': bidNotify,
      'userId': userId,
      'customData': customData,
      'rewardName': rewardName,
      'rewardAmount': rewardAmount,
    });
  }
}

@immutable
final class GromoreInterstitialRequest {
  const GromoreInterstitialRequest({
    required this.slotId,
    this.muted = false,
    this.orientation = GromoreAdOrientation.vertical,
    this.useSurfaceView = true,
    this.bidNotify = false,
  });

  final String slotId;
  final bool muted;
  final GromoreAdOrientation orientation;
  final bool useSurfaceView;
  final bool bidNotify;

  Map<String, Object> toMap() {
    _checkSlotId(slotId);
    return <String, Object>{
      'slotId': slotId,
      'muted': muted,
      'orientation': orientation.nativeValue,
      'useSurfaceView': useSurfaceView,
      'bidNotify': bidNotify,
    };
  }
}

@immutable
final class GromoreBannerRequest {
  const GromoreBannerRequest({
    required this.slotId,
    required this.width,
    required this.height,
    this.bidNotify = false,
  });

  final String slotId;
  final double width;
  final double height;
  final bool bidNotify;

  Map<String, Object> toMap() => _sizedViewMap(
        slotId: slotId,
        width: width,
        height: height,
        values: <String, Object>{'bidNotify': bidNotify},
      );
}

@immutable
final class GromoreFeedRequest {
  const GromoreFeedRequest({
    required this.slotId,
    required this.width,
    required this.height,
    this.muted = false,
    this.useSurfaceView = true,
    this.bidNotify = false,
  });

  final String slotId;
  final double width;
  final double height;
  final bool muted;
  final bool useSurfaceView;
  final bool bidNotify;

  Map<String, Object> toMap() => _sizedViewMap(
        slotId: slotId,
        width: width,
        height: height,
        values: <String, Object>{
          'muted': muted,
          'useSurfaceView': useSurfaceView,
          'bidNotify': bidNotify,
        },
      );
}

@immutable
final class GromoreDrawFeedRequest {
  const GromoreDrawFeedRequest({
    required this.slotId,
    required this.width,
    required this.height,
    this.muted = false,
    this.useSurfaceView = true,
    this.bidNotify = false,
  });

  final String slotId;
  final double width;
  final double height;
  final bool muted;
  final bool useSurfaceView;
  final bool bidNotify;

  Map<String, Object> toMap() => _sizedViewMap(
        slotId: slotId,
        width: width,
        height: height,
        values: <String, Object>{
          'muted': muted,
          'useSurfaceView': useSurfaceView,
          'bidNotify': bidNotify,
        },
      );
}

enum GromoreAdType {
  sdk,
  splash,
  rewarded,
  interstitial,
  banner,
  feed,
  drawFeed,
  unknown;

  static GromoreAdType fromWire(String? value) => switch (value) {
        'sdk' => sdk,
        'splash' => splash,
        'rewarded' => rewarded,
        'interstitial' => interstitial,
        'banner' => banner,
        'feed' => feed,
        'drawFeed' => drawFeed,
        _ => unknown,
      };
}

/// Network condition required before GroMore receives a preload request.
enum GromorePreloadNetwork {
  /// Submit only while the active network is Wi-Fi.
  wifiOnly('wifiOnly'),

  /// Submit on any available network, including Wi-Fi and cellular.
  any('any');

  const GromorePreloadNetwork(this.nativeValue);
  final String nativeValue;
}

/// Result of attempting to submit a first-precache request to GroMore.
///
/// [requested] means that the request was handed to the native SDK. GroMore's
/// preload API does not expose a completion callback, so it does not guarantee
/// that every configured placement has already cached an ad.
enum GromorePreloadResult {
  requested,
  skippedNoNetwork,
  skippedNotWifi;

  static GromorePreloadResult fromWire(String? value) => switch (value) {
        'requested' => requested,
        'skippedNoNetwork' => skippedNoNetwork,
        'skippedNotWifi' => skippedNotWifi,
        _ => throw FormatException('Invalid GroMore preload result: $value'),
      };
}

/// One placement passed to GroMore's native first-precache API.
///
/// GroMore currently supports first precaching for splash, rewarded,
/// interstitial/full-screen and feed placements. Banner and Draw are omitted
/// intentionally because the native SDK does not support them.
@immutable
final class GromorePreloadItem {
  const GromorePreloadItem.splash(GromoreSplashRequest request)
      : adType = GromoreAdType.splash,
        _request = request;

  const GromorePreloadItem.rewarded(GromoreRewardedRequest request)
      : adType = GromoreAdType.rewarded,
        _request = request;

  const GromorePreloadItem.interstitial(GromoreInterstitialRequest request)
      : adType = GromoreAdType.interstitial,
        _request = request;

  const GromorePreloadItem.feed(GromoreFeedRequest request)
      : adType = GromoreAdType.feed,
        _request = request;

  final GromoreAdType adType;
  final Object _request;

  String get slotId => switch (_request) {
        GromoreSplashRequest request => request.slotId,
        GromoreRewardedRequest request => request.slotId,
        GromoreInterstitialRequest request => request.slotId,
        GromoreFeedRequest request => request.slotId,
        _ => throw StateError('Unsupported GroMore preload request.'),
      };

  Map<String, Object> toMap() {
    final Map<String, Object> request = switch (_request) {
      GromoreSplashRequest value => value.toMap(),
      GromoreRewardedRequest value => value.toMap(),
      GromoreInterstitialRequest value => value.toMap(),
      GromoreFeedRequest value => value.toMap(),
      _ => throw StateError('Unsupported GroMore preload request.'),
    };
    final String adTypeValue = switch (adType) {
      GromoreAdType.splash => 'splash',
      GromoreAdType.rewarded => 'rewarded',
      GromoreAdType.interstitial => 'interstitial',
      GromoreAdType.feed => 'feed',
      _ => throw StateError('Unsupported GroMore preload ad type: $adType'),
    };
    return <String, Object>{
      'adType': adTypeValue,
      'request': request,
    };
  }
}

/// Configuration for GroMore's first-precache request.
@immutable
final class GromorePreloadConfig {
  const GromorePreloadConfig({
    required this.items,
    this.network = GromorePreloadNetwork.wifiOnly,
    this.interval = const Duration(seconds: 2),
    this.concurrent = 2,
  });

  final List<GromorePreloadItem> items;
  final GromorePreloadNetwork network;
  final Duration interval;
  final int concurrent;

  Map<String, Object> toMap() {
    if (items.isEmpty || items.length > 20) {
      throw ArgumentError.value(
        items.length,
        'items',
        'Must contain between 1 and 20 placements.',
      );
    }
    if (interval < const Duration(seconds: 1) ||
        interval > const Duration(seconds: 10) ||
        interval.inMilliseconds % Duration.millisecondsPerSecond != 0) {
      throw ArgumentError.value(
        interval,
        'interval',
        'Must be a whole number of seconds between 1 and 10.',
      );
    }
    if (concurrent < 1 || concurrent > 20) {
      throw ArgumentError.value(
        concurrent,
        'concurrent',
        'Must be between 1 and 20.',
      );
    }

    final Set<String> placements = <String>{};
    final List<Map<String, Object>> serialized = <Map<String, Object>>[];
    for (final GromorePreloadItem item in items) {
      final Map<String, Object> value = item.toMap();
      final String key = '${value['adType']}/${item.slotId}';
      if (!placements.add(key)) {
        throw ArgumentError.value(
          item.slotId,
          'items',
          'Duplicate preload placement: $key.',
        );
      }
      serialized.add(value);
    }

    return <String, Object>{
      'items': serialized,
      'network': network.nativeValue,
      'intervalSeconds': interval.inSeconds,
      'concurrent': concurrent,
    };
  }
}

enum GromoreAdEventType {
  initialized,
  loadSuccess,
  loaded,
  rendered,
  renderFailed,
  shown,
  showFailed,
  clicked,
  closed,
  skipped,
  completed,
  videoError,
  rewardEarned,
  rewardFailed,
  disliked,
  videoStarted,
  videoPaused,
  videoResumed,
  videoStateChanged,
  disposed,
  failed,
  unknown;

  static GromoreAdEventType fromWire(String? value) => switch (value) {
        'initialized' => initialized,
        'loadSuccess' => loadSuccess,
        'loaded' => loaded,
        'rendered' => rendered,
        'renderFailed' => renderFailed,
        'shown' => shown,
        'showFailed' => showFailed,
        'clicked' => clicked,
        'closed' => closed,
        'skipped' => skipped,
        'completed' => completed,
        'videoError' => videoError,
        'rewardEarned' => rewardEarned,
        'rewardFailed' => rewardFailed,
        'disliked' => disliked,
        'videoStarted' => videoStarted,
        'videoPaused' => videoPaused,
        'videoResumed' => videoResumed,
        'videoStateChanged' => videoStateChanged,
        'disposed' => disposed,
        'failed' => failed,
        _ => unknown,
      };
}

@immutable
final class GromoreAdEvent {
  const GromoreAdEvent({
    required this.type,
    required this.adType,
    this.requestId,
    this.code,
    this.message,
    this.ecpm,
    this.adnName,
    this.slotId,
    this.adnSlotId,
    this.networkRequestId,
    this.rewardValid,
    this.rewardType,
    this.rewardName,
    this.rewardAmount,
    this.closeReason,
    this.extra = const <String, Object?>{},
  });

  factory GromoreAdEvent.fromMap(Map<Object?, Object?> map) {
    final Map<String, Object?> normalized = <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in map.entries)
        if (entry.key is String) entry.key! as String: entry.value,
    };
    final Object? rawExtra = normalized['extra'];
    return GromoreAdEvent(
      type: GromoreAdEventType.fromWire(normalized['event'] as String?),
      adType: GromoreAdType.fromWire(normalized['adType'] as String?),
      requestId: normalized['requestId'] as String?,
      code: (normalized['code'] as num?)?.toInt(),
      message: normalized['message'] as String?,
      ecpm: normalized['ecpm']?.toString(),
      adnName: normalized['adnName'] as String?,
      slotId: normalized['slotId'] as String?,
      adnSlotId: normalized['adnSlotId'] as String?,
      networkRequestId: normalized['networkRequestId'] as String?,
      rewardValid: normalized['rewardValid'] as bool?,
      rewardType: (normalized['rewardType'] as num?)?.toInt(),
      rewardName: normalized['rewardName'] as String?,
      rewardAmount: (normalized['rewardAmount'] as num?)?.toInt(),
      closeReason: (normalized['closeReason'] as num?)?.toInt(),
      extra: rawExtra is Map
          ? <String, Object?>{
              for (final MapEntry<Object?, Object?> entry in rawExtra.entries)
                if (entry.key is String) entry.key! as String: entry.value,
            }
          : const <String, Object?>{},
    );
  }

  final GromoreAdEventType type;
  final GromoreAdType adType;
  final String? requestId;
  final int? code;
  final String? message;
  final String? ecpm;
  final String? adnName;
  final String? slotId;
  final String? adnSlotId;
  final String? networkRequestId;
  final bool? rewardValid;
  final int? rewardType;
  final String? rewardName;
  final int? rewardAmount;
  final int? closeReason;
  final Map<String, Object?> extra;
}

enum GromoreTrackingStatus {
  notSupported,
  notDetermined,
  restricted,
  denied,
  authorized;

  static GromoreTrackingStatus fromWire(String? value) => switch (value) {
        'notDetermined' => notDetermined,
        'restricted' => restricted,
        'denied' => denied,
        'authorized' => authorized,
        _ => notSupported,
      };
}

void _checkSlotId(String value) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, 'slotId', 'Slot ID must not be empty.');
  }
}

Map<String, Object> _withoutNullValues(Map<String, Object?> values) =>
    <String, Object>{
      for (final MapEntry<String, Object?> entry in values.entries)
        if (entry.value != null) entry.key: entry.value!,
    };

Map<String, Object> _sizedViewMap({
  required String slotId,
  required double width,
  required double height,
  required Map<String, Object> values,
}) {
  _checkSlotId(slotId);
  if (!width.isFinite || width <= 0) {
    throw ArgumentError.value(width, 'width', 'Must be finite and positive.');
  }
  if (!height.isFinite || height <= 0) {
    throw ArgumentError.value(height, 'height', 'Must be finite and positive.');
  }
  return <String, Object>{
    'slotId': slotId,
    'width': width,
    'height': height,
    ...values,
  };
}
