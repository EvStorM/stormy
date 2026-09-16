import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';

final class StormyGromore {
  StormyGromore({
    MethodChannel methodChannel = const MethodChannel(_methodChannelName),
    EventChannel eventChannel = const EventChannel(_eventChannelName),
  })  : _methodChannel = methodChannel,
        _eventChannel = eventChannel;

  static const String _methodChannelName = 'stormy_gromore/methods';
  static const String _eventChannelName = 'stormy_gromore/events';

  static final StormyGromore instance = StormyGromore();

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  bool _initialized = false;
  Future<void>? _initialization;
  Stream<GromoreAdEvent>? _events;
  int _requestSequence = 0;

  bool get isInitialized => _initialized;

  Stream<GromoreAdEvent> get events => _events ??= _eventChannel
          .receiveBroadcastStream()
          .map<GromoreAdEvent>((Object? value) {
        if (value is! Map) {
          throw FormatException('Invalid GroMore event: $value');
        }
        return GromoreAdEvent.fromMap(value);
      });

  Future<void> initialize(GromoreConfig config) {
    if (_initialized) {
      return SynchronousFuture<void>(null);
    }
    return _initialization ??= _initialize(config);
  }

  Future<void> _initialize(GromoreConfig config) async {
    try {
      final bool ready = await _methodChannel.invokeMethod<bool>(
            'initialize',
            config.toMap(),
          ) ??
          false;
      if (!ready) {
        throw StateError('GroMore initialization did not become ready.');
      }
      _initialized = true;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<GromoreTrackingStatus> requestTrackingAuthorization() async {
    final String? value = await _methodChannel.invokeMethod<String>(
      'requestTrackingAuthorization',
    );
    return GromoreTrackingStatus.fromWire(value);
  }

  Future<String> loadSplash(GromoreSplashRequest request) =>
      _load('loadSplash', 'splash', request.toMap());

  Future<bool> showSplash(String requestId) => _show('showSplash', requestId);

  Future<String> loadRewarded(GromoreRewardedRequest request) =>
      _load('loadRewarded', 'rewarded', request.toMap());

  Future<bool> showRewarded(String requestId) =>
      _show('showRewarded', requestId);

  Future<String> loadInterstitial(GromoreInterstitialRequest request) =>
      _load('loadInterstitial', 'interstitial', request.toMap());

  Future<bool> showInterstitial(String requestId) =>
      _show('showInterstitial', requestId);

  /// Requests GroMore to pre-cache the configured placements.
  ///
  /// The native bridge checks [GromorePreloadConfig.network] immediately
  /// before submitting. A skipped result does not stay queued; call this again
  /// after the network changes. The later load request must use the same
  /// request parameters to hit GroMore's cache.
  Future<GromorePreloadResult> preloadAds(GromorePreloadConfig config) async {
    _ensureInitialized();
    final String? value = await _methodChannel.invokeMethod<String>(
      'preloadAds',
      config.toMap(),
    );
    return GromorePreloadResult.fromWire(value);
  }

  Future<void> disposeAd(String requestId) async {
    _ensureInitialized();
    _checkRequestId(requestId);
    await _methodChannel.invokeMethod<void>('disposeAd', <String, Object>{
      'requestId': requestId,
    });
  }

  /// Creates a Flutter-owned ID for a platform-view ad.
  ///
  /// Pass the value to a banner/feed widget and use it to filter [events].
  String createViewRequestId(GromoreAdType adType) {
    if (adType != GromoreAdType.banner &&
        adType != GromoreAdType.feed &&
        adType != GromoreAdType.drawFeed) {
      throw ArgumentError.value(adType, 'adType', 'Must be a view ad type.');
    }
    return _nextRequestId(adType.name);
  }

  Future<String> _load(
    String method,
    String adType,
    Map<String, Object> request,
  ) async {
    _ensureInitialized();
    final String requestId = _nextRequestId(adType);
    final String? accepted = await _methodChannel.invokeMethod<String>(
      method,
      <String, Object>{...request, 'requestId': requestId},
    );
    if (accepted != requestId) {
      throw StateError('Native GroMore bridge rejected request $requestId.');
    }
    return requestId;
  }

  Future<bool> _show(String method, String requestId) async {
    _ensureInitialized();
    _checkRequestId(requestId);
    return await _methodChannel.invokeMethod<bool>(method, <String, Object>{
          'requestId': requestId,
        }) ??
        false;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'Call and await StormyGromore.initialize after privacy consent first.',
      );
    }
  }

  String _nextRequestId(String adType) {
    _requestSequence += 1;
    return '$adType-${DateTime.now().microsecondsSinceEpoch}-$_requestSequence';
  }
}

void _checkRequestId(String value) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(
      value,
      'requestId',
      'Request ID must not be empty.',
    );
  }
}
