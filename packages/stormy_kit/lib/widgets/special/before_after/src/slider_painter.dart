import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../before_after.dart';

/// A custom painter for rendering a slider.
///
/// The `SliderPainter` class is a custom painter that renders a slider with a track and a thumb.
/// It extends the [ChangeNotifier] class and implements the [CustomPainter] class.
///
/// The slider can be configured with various properties such as the axis (horizontal or vertical),
/// the current value, track width and color, thumb size and decoration, and more.
///
/// Example usage:
///
/// ```dart
/// SliderPainter painter = SliderPainter(
///   overlayAnimation: AnimationController(
///     vsync: this,
///     duration: Duration(milliseconds: 100),
///   ),
/// );
/// painter.axis = SliderDirection.horizontal;
/// painter.value = 0.5;
/// painter.trackWidth = 4.0;
/// painter.trackColor = Colors.grey;
/// painter.thumbValue = 0.5;
/// painter.thumbWidth = 20.0;
/// painter.thumbHeight = 40.0;
/// painter.thumbDecoration = BoxDecoration(
///   color: Colors.blue,
///   shape: BoxShape.circle,
/// );
///
/// CustomPaint(
///   painter: painter,
///   child: Container(
///     // Child widget
///   ),
/// )
/// ```
class SliderPainter extends ChangeNotifier implements CustomPainter {
  /// Creates a slider painter.
  SliderPainter({
    required Animation<double> overlayAnimation,
    ValueSetter<Rect>? onThumbRectChanged,
  }) : _overlayAnimation = overlayAnimation,
       _onThumbRectChanged = onThumbRectChanged {
    _overlayAnimation.addListener(notifyListeners);
  }

  /// The animation of the thumb overlay.
  final Animation<double> _overlayAnimation;

  /// Callback to notify when the thumb rect changes.
  final ValueSetter<Rect>? _onThumbRectChanged;

  /// The axis of the slider.
  SliderDirection get axis => _axis!;
  SliderDirection? _axis;

  set axis(SliderDirection value) {
    if (_axis != value) {
      _axis = value;
      notifyListeners();
    }
  }

  /// The current value of the slider.
  double get value => _value!;
  double? _value;

  set value(double value) {
    if (_value != value) {
      _value = value;
      notifyListeners();
    }
  }

  /// The width of the track.
  double get trackWidth => _trackWidth!;
  double? _trackWidth;

  set trackWidth(double value) {
    if (_trackWidth != value) {
      _trackWidth = value;
      notifyListeners();
    }
  }

  /// The color or gradient of the track.
  ///
  /// Can be either a [Color] for solid color or a [Gradient] for linear gradient.
  Object get trackColor => _trackColor!;
  Object? _trackColor;

  set trackColor(Object value) {
    if (_trackColor != value) {
      _trackColor = value;
      notifyListeners();
    }
  }

  /// The value of the thumb.
  double get thumbValue => _thumbValue!;
  double? _thumbValue;

  set thumbValue(double value) {
    if (_thumbValue != value) {
      _thumbValue = value;
      notifyListeners();
    }
  }

  /// The width of the thumb.
  double get thumbWidth => _thumbWidth!;
  double? _thumbWidth;

  set thumbWidth(double value) {
    if (_thumbWidth != value) {
      _thumbWidth = value;
      notifyListeners();
    }
  }

  /// The height of the thumb.
  double get thumbHeight => _thumbHeight!;
  double? _thumbHeight;

  set thumbHeight(double value) {
    if (_thumbHeight != value) {
      _thumbHeight = value;
      notifyListeners();
    }
  }

  /// The color of the thumb overlay.
  Color get overlayColor => _overlayColor!;
  Color? _overlayColor;

  set overlayColor(Color value) {
    if (_overlayColor != value) {
      _overlayColor = value;
      notifyListeners();
    }
  }

  /// The decoration of the thumb.
  BoxDecoration get thumbDecoration => _thumbDecoration!;
  BoxDecoration? _thumbDecoration;

  set thumbDecoration(BoxDecoration? value) {
    if (_thumbDecoration != value) {
      _thumbDecoration = value;

      // Dispose and reset the thumb painter if it exists.
      _thumbPainter?.dispose();
      _thumbPainter = null;

      notifyListeners();
    }
  }

  /// The image configuration for the thumb.
  ImageConfiguration get configuration => _configuration!;
  ImageConfiguration? _configuration;

  set configuration(ImageConfiguration value) {
    if (_configuration != value) {
      _configuration = value;
      notifyListeners();
    }
  }

  /// Whether to hide the thumb.
  bool get hideThumb => _hideThumb!;
  bool? _hideThumb;

  set hideThumb(bool value) {
    if (_hideThumb != value) {
      _hideThumb = value;
      notifyListeners();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Clip the canvas to the size of the slider so that we don't draw outside.
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final isHorizontal = axis == SliderDirection.horizontal;

    // If the thumb is hidden, draw a straight track.
    if (hideThumb) {
      final startOffset = Offset(
        isHorizontal ? size.width * value : 0.0,
        isHorizontal ? 0.0 : size.height * value,
      );
      final endOffset = Offset(
        isHorizontal ? size.width * value : size.width,
        isHorizontal ? size.height : size.height * value,
      );
      _drawTrackSegment(canvas, startOffset, endOffset, isHorizontal, size);
      return;
    }

    // Draw track (first and second half).
    // First half
    final firstStart = Offset(
      isHorizontal ? size.width * value : 0.0,
      isHorizontal ? 0.0 : size.height * value,
    );
    final firstEnd = Offset(
      isHorizontal
          ? size.width * value
          : size.width * thumbValue - (thumbHeight / 2),
      isHorizontal
          ? size.height * thumbValue - (thumbHeight / 2)
          : size.height * value,
    );
    _drawTrackSegment(canvas, firstStart, firstEnd, isHorizontal, size);

    // Second half
    final secondStart = Offset(
      isHorizontal
          ? size.width * value
          : size.width * thumbValue + thumbHeight / 2,
      isHorizontal
          ? size.height * thumbValue + thumbHeight / 2
          : size.height * value,
    );
    final secondEnd = Offset(
      isHorizontal ? size.width * value : size.width,
      isHorizontal ? size.height : size.height * value,
    );
    _drawTrackSegment(canvas, secondStart, secondEnd, isHorizontal, size);

    // Calculate the thumb rect.
    final thumbRect = Rect.fromCenter(
      center: Offset(
        isHorizontal ? size.width * value : size.width * thumbValue,
        isHorizontal ? size.height * thumbValue : size.height * value,
      ),
      width: isHorizontal ? thumbWidth : thumbHeight,
      height: isHorizontal ? thumbHeight : thumbWidth,
    );

    // Notify the listener of the thumb rect.
    _onThumbRectChanged?.call(thumbRect);

    // Draw the thumb overlay.
    if (!_overlayAnimation.isDismissed) {
      const lengthMultiplier = 2;

      final overlayRect = Rect.fromCenter(
        center: thumbRect.center,
        width: thumbRect.width * lengthMultiplier * _overlayAnimation.value,
        height: thumbRect.height * lengthMultiplier * _overlayAnimation.value,
      );

      // Draw the overlay.
      _drawOverlay(canvas, overlayRect);
    }

    // Draw the thumb.
    _drawThumb(canvas, thumbRect);
  }

  /// Draws a track segment from start to end, supporting both Color and Gradient.
  void _drawTrackSegment(
    Canvas canvas,
    Offset start,
    Offset end,
    bool isHorizontal,
    Size size,
  ) {
    final trackPaint = Paint()..strokeWidth = trackWidth;

    if (trackColor is Gradient) {
      // For gradient, we need to draw a rectangle instead of a line
      final gradient = trackColor as Gradient;

      // Calculate the rectangle bounds for the track
      Rect trackRect;
      if (isHorizontal) {
        // Horizontal track: draw a vertical rectangle (width = trackWidth, height spans from start to end)
        final centerX = start.dx;
        final halfWidth = trackWidth / 2;
        final minY = start.dy < end.dy ? start.dy : end.dy;
        final maxY = start.dy > end.dy ? start.dy : end.dy;
        final height = (maxY - minY).abs();
        // If height is 0, use full height
        final finalHeight = height > 0 ? height : size.height;
        trackRect = Rect.fromLTWH(
          centerX - halfWidth,
          minY,
          trackWidth,
          finalHeight,
        );
      } else {
        // Vertical track: draw a horizontal rectangle (height = trackWidth, width spans from start to end)
        final centerY = start.dy;
        final halfWidth = trackWidth / 2;
        final minX = start.dx < end.dx ? start.dx : end.dx;
        final maxX = start.dx > end.dx ? start.dx : end.dx;
        final width = (maxX - minX).abs();
        // If width is 0, use full width
        final finalWidth = width > 0 ? width : size.width;
        trackRect = Rect.fromLTWH(
          minX,
          centerY - halfWidth,
          finalWidth,
          trackWidth,
        );
      }

      // Create shader for the gradient
      // Use the gradient as provided by the user, respecting their direction settings
      trackPaint.shader = gradient.createShader(trackRect);
      trackPaint.style = PaintingStyle.fill;
      canvas.drawRect(trackRect, trackPaint);
    } else {
      // For solid color, use drawLine for backward compatibility
      trackPaint.color = trackColor as Color;
      trackPaint.style = PaintingStyle.stroke;
      canvas.drawLine(start, end, trackPaint);
    }
  }

  void _drawOverlay(Canvas canvas, Rect overlayRect) {
    Path? overlayPath;
    switch (thumbDecoration.shape) {
      case BoxShape.circle:
        assert(thumbDecoration.borderRadius == null);
        final Offset center = overlayRect.center;
        final double radius = overlayRect.shortestSide / 2.0;
        final Rect square = Rect.fromCircle(center: center, radius: radius);
        overlayPath = Path()..addOval(square);
        break;
      case BoxShape.rectangle:
        if (thumbDecoration.borderRadius == null ||
            thumbDecoration.borderRadius == BorderRadius.zero) {
          overlayPath = Path()..addRect(overlayRect);
        } else {
          overlayPath = Path()
            ..addRRect(
              thumbDecoration.borderRadius!
                  .resolve(configuration.textDirection)
                  .toRRect(overlayRect),
            );
        }
        break;
    }

    canvas.drawPath(overlayPath, Paint()..color = overlayColor);
  }

  bool _isPainting = false;

  void _handleThumbChange() {
    // If the thumb decoration is available synchronously, we'll get called here
    // during paint. There's no reason to mark ourselves as needing paint if we
    // are already in the middle of painting. (In fact, doing so would trigger
    // an assert).
    if (!_isPainting) {
      notifyListeners();
    }
  }

  BoxPainter? _thumbPainter;

  void _drawThumb(Canvas canvas, Rect thumbRect) {
    try {
      _isPainting = true;
      if (_thumbPainter == null) {
        _thumbPainter?.dispose();
        _thumbPainter = thumbDecoration.createBoxPainter(_handleThumbChange);
      }
      final config = configuration.copyWith(size: thumbRect.size);
      _thumbPainter!.paint(canvas, thumbRect.topLeft, config);
    } finally {
      _isPainting = false;
    }
  }

  @override
  void dispose() {
    _thumbPainter?.dispose();
    _thumbPainter = null;
    _overlayAnimation.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  bool shouldRepaint(covariant SliderPainter oldDelegate) => false;

  @override
  bool? hitTest(Offset position) => null;

  @override
  SemanticsBuilderCallback? get semanticsBuilder => null;

  @override
  bool shouldRebuildSemantics(covariant CustomPainter oldDelegate) => false;

  @override
  String toString() => describeIdentity(this);
}
