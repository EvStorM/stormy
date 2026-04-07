import 'package:flutter/material.dart';

import '../../../stormy_kit.dart';

class AppModel {
  final Size designSize;
  final String title;
  final Widget Function(String)? loadingBuilder;
  final Widget Function(String)? toastBuilder;

  AppModel({
    required this.designSize,
    required this.title,
    this.loadingBuilder,
    this.toastBuilder,
  });

  factory AppModel.defaults() {
    return AppModel(
      designSize: Size(375, 812),
      title: 'StormyKit',
      loadingBuilder: (msg) => CustomLoading(msg: msg),
      toastBuilder: (msg) => CustomToast(msg),
    );
  }

  AppModel copyWith({Size? designSize, String? title}) {
    return AppModel(
      designSize: designSize ?? this.designSize,
      title: title ?? this.title,
    );
  }
}
