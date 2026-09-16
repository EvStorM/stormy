import 'package:flutter/material.dart';

/// 圆角填充器 - 用于创建凹角效果
///
/// 当两个带圆角的容器相邻时，在它们的交界处创建一个凹角效果
/// 通过裁剪掉一个圆角来实现反向圆角的视觉效果
class CornerFiller extends StatelessWidget {
  const CornerFiller({
    super.key,
    required this.size,
    required this.backgroundColor,
    this.corner = CornerPosition.topLeft,
  });

  /// 凹角的大小（圆角半径）
  final double size;

  /// 背景色（通常是下层容器的颜色）
  final Color backgroundColor;

  /// 凹角的位置
  final CornerPosition corner;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CornerFillerPainter(
        backgroundColor: backgroundColor,
        corner: corner,
      ),
    );
  }
}

/// 凹角位置枚举
enum CornerPosition { topLeft, topRight, bottomLeft, bottomRight }

/// 凹角绘制器
class _CornerFillerPainter extends CustomPainter {
  _CornerFillerPainter({required this.backgroundColor, required this.corner});

  final Color backgroundColor;
  final CornerPosition corner;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final path = Path();

    // 根据凹角位置绘制不同的路径
    switch (corner) {
      case CornerPosition.topLeft:
        // 左上凹角：从左下开始，经过右下、右上（圆弧），到左上
        path.moveTo(0, size.height); // 左下
        path.lineTo(size.width, size.height); // 右下
        path.lineTo(size.width, 0); // 右上
        path.arcToPoint(
          Offset(0, size.height),
          radius: Radius.circular(size.width),
          clockwise: false,
        );
        break;

      case CornerPosition.topRight:
        // 右上凹角：从右下开始，经过左下、左上（圆弧），到右下
        path.moveTo(size.width, size.height); // 右下
        path.lineTo(0, size.height); // 左下
        path.lineTo(0, 0); // 左上
        path.arcToPoint(
          Offset(size.width, size.height),
          radius: Radius.circular(size.width),
          clockwise: false,
        );
        break;

      case CornerPosition.bottomLeft:
        // 左下凹角：从左上开始，经过右上、右下（圆弧），到左上
        path.moveTo(0, 0); // 左上
        path.lineTo(size.width, 0); // 右上
        path.lineTo(size.width, size.height); // 右下
        path.arcToPoint(
          Offset(0, 0),
          radius: Radius.circular(size.width),
          clockwise: false,
        );
        break;

      case CornerPosition.bottomRight:
        // 右下凹角：从右上开始，经过左上、左下（圆弧），到右上
        path.moveTo(size.width, 0); // 右上
        path.lineTo(0, 0); // 左上
        path.lineTo(0, size.height); // 左下
        path.arcToPoint(
          Offset(size.width, 0),
          radius: Radius.circular(size.width),
          clockwise: false,
        );
        break;
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerFillerPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.corner != corner;
  }
}
