import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class BaseParent extends SingleChildRenderObjectWidget {
  const BaseParent({super.key, required Widget child}) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderParent();
  }
}

class _RenderParent extends RenderProxyBox {
  @override
  void performLayout() {
    child!.layout(BoxConstraints.loose(Size.infinite), parentUsesSize: true);
    size = child!.size; // 父组件尺寸由子组件决定
  }
}
