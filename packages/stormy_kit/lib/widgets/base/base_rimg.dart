import 'package:flutter/material.dart';

class GrowTransition extends StatelessWidget {
  const GrowTransition({super.key, required this.animation, this.child});

  final Widget? child;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, child) {
          return Stack(
            children: [
              Positioned(
                top: 0,
                left: animation.value,
                child: child ?? const SizedBox.shrink(),
              ),
            ],
          );
        },
        child: child,
      ),
    );
  }
}
