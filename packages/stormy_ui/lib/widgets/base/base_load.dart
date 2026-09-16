import 'package:fade_shimmer/fade_shimmer.dart';
import 'package:flutter/material.dart';

class BaseLoad extends StatelessWidget {
  const BaseLoad({
    super.key,
    this.isLoading = true,
    this.child,
    this.height = 80,
    this.width = 120,
    this.radius = 16,
    this.baseColor,
    this.highlightColor,
  });
  final bool isLoading;
  final Widget? child;
  final double height;
  final double width;
  final double radius;
  final Color? baseColor;
  final Color? highlightColor;
  @override
  Widget build(BuildContext context) {
    if (!isLoading) {
      return child ?? const SizedBox.shrink();
    }
    return FadeShimmer(
      height: height,
      width: width,
      radius: radius,
      baseColor: baseColor ?? Colors.grey[300]!,
      highlightColor: highlightColor ?? Colors.grey[100]!,
    );
  }
}
