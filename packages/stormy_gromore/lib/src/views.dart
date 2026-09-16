import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'models.dart';

typedef GromoreViewCreatedCallback = void Function(String requestId);

final class GromoreBannerView extends StatelessWidget {
  const GromoreBannerView({
    required this.requestId,
    required this.request,
    this.onPlatformViewCreated,
    super.key,
  });

  final String requestId;
  final GromoreBannerRequest request;
  final GromoreViewCreatedCallback? onPlatformViewCreated;

  @override
  Widget build(BuildContext context) => _GromorePlatformView(
        viewType: 'stormy_gromore/banner',
        requestId: requestId,
        width: request.width,
        height: request.height,
        creationParams: request.toMap(),
        onPlatformViewCreated: onPlatformViewCreated,
      );
}

/// Displays a GroMore template feed ad.
///
/// Configure the GroMore placement as template-rendered. Native self-rendered
/// feed creatives are rejected because they require an app-specific compliant
/// layout and cannot be safely synthesized by a generic Flutter plugin.
final class GromoreFeedView extends StatelessWidget {
  const GromoreFeedView({
    required this.requestId,
    required this.request,
    this.onPlatformViewCreated,
    super.key,
  });

  final String requestId;
  final GromoreFeedRequest request;
  final GromoreViewCreatedCallback? onPlatformViewCreated;

  @override
  Widget build(BuildContext context) => _GromorePlatformView(
        viewType: 'stormy_gromore/feed',
        requestId: requestId,
        width: request.width,
        height: request.height,
        creationParams: request.toMap(),
        onPlatformViewCreated: onPlatformViewCreated,
      );
}

/// Displays a GroMore template Draw feed ad.
final class GromoreDrawFeedView extends StatelessWidget {
  const GromoreDrawFeedView({
    required this.requestId,
    required this.request,
    this.onPlatformViewCreated,
    super.key,
  });

  final String requestId;
  final GromoreDrawFeedRequest request;
  final GromoreViewCreatedCallback? onPlatformViewCreated;

  @override
  Widget build(BuildContext context) => _GromorePlatformView(
        viewType: 'stormy_gromore/draw_feed',
        requestId: requestId,
        width: request.width,
        height: request.height,
        creationParams: request.toMap(),
        onPlatformViewCreated: onPlatformViewCreated,
      );
}

final class _GromorePlatformView extends StatelessWidget {
  const _GromorePlatformView({
    required this.viewType,
    required this.requestId,
    required this.width,
    required this.height,
    required this.creationParams,
    this.onPlatformViewCreated,
  });

  final String viewType;
  final String requestId;
  final double width;
  final double height;
  final Map<String, Object> creationParams;
  final GromoreViewCreatedCallback? onPlatformViewCreated;

  @override
  Widget build(BuildContext context) {
    if (requestId.trim().isEmpty) {
      throw ArgumentError.value(
        requestId,
        'requestId',
        'Request ID must not be empty.',
      );
    }
    final Map<String, Object> params = <String, Object>{
      ...creationParams,
      'requestId': requestId,
    };
    void callback(int _) {
      onPlatformViewCreated?.call(requestId);
    }

    final Widget view = switch (defaultTargetPlatform) {
      TargetPlatform.android => PlatformViewLink(
          key: ValueKey<String>('$viewType/$requestId'),
          viewType: viewType,
          surfaceFactory: (
            BuildContext context,
            PlatformViewController controller,
          ) =>
              AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          ),
          onCreatePlatformView: (PlatformViewCreationParams creation) =>
              PlatformViewsService.initSurfaceAndroidView(
            id: creation.id,
            viewType: viewType,
            layoutDirection:
                Directionality.maybeOf(context) ?? TextDirection.ltr,
            creationParams: params,
            creationParamsCodec: const StandardMessageCodec(),
            onFocus: () => creation.onFocusChanged(true),
          )
                ..addOnPlatformViewCreatedListener(
                  creation.onPlatformViewCreated,
                )
                ..addOnPlatformViewCreatedListener(callback)
                ..create(),
        ),
      TargetPlatform.iOS => UiKitView(
          key: ValueKey<String>('$viewType/$requestId'),
          viewType: viewType,
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: callback,
        ),
      _ => throw UnsupportedError(
          'stormy_gromore view ads only support Android and iOS.',
        ),
    };
    return SizedBox(width: width, height: height, child: view);
  }
}
