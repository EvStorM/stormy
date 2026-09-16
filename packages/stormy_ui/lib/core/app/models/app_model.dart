import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../widgets/special/toast/custom_loading_widget.dart';
import '../../../widgets/special/toast/custom_toast_widget.dart';

class AppModel {
  static const Object _unsetBuilder = Object();

  final Size designSize;
  final String title;
  final Widget Function(String)? loadingBuilder;
  final Widget Function(String)? toastBuilder;
  final List<DeviceOrientation> preferredOrientations;

  AppModel({
    required this.designSize,
    required this.title,
    this.loadingBuilder,
    this.toastBuilder,
    this.preferredOrientations = const [DeviceOrientation.portraitUp],
  });

  factory AppModel.defaults() {
    return AppModel(
      designSize: Size(375, 812),
      title: 'StormyKit',
      loadingBuilder: (msg) => CustomLoading(msg: msg),
      toastBuilder: (msg) => CustomToast(msg),
      preferredOrientations: const [DeviceOrientation.portraitUp],
    );
  }

  AppModel copyWith({
    Size? designSize,
    String? title,
    Object? loadingBuilder = _unsetBuilder,
    Object? toastBuilder = _unsetBuilder,
    List<DeviceOrientation>? preferredOrientations,
  }) {
    return AppModel(
      designSize: designSize ?? this.designSize,
      title: title ?? this.title,
      loadingBuilder: identical(loadingBuilder, _unsetBuilder)
          ? this.loadingBuilder
          : loadingBuilder as Widget Function(String)?,
      toastBuilder: identical(toastBuilder, _unsetBuilder)
          ? this.toastBuilder
          : toastBuilder as Widget Function(String)?,
      preferredOrientations:
          preferredOrientations ?? this.preferredOrientations,
    );
  }
}
