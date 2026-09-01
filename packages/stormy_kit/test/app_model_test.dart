import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stormy_kit/stormy_kit.dart';

void main() {
  group('AppModel', () {
    test('defaults to portrait-up orientation', () {
      final model = AppModel.defaults();

      expect(model.preferredOrientations, const [DeviceOrientation.portraitUp]);
    });

    test('copyWith retains and replaces every field', () {
      Widget loadingBuilder(String message) => Text('loading:$message');
      Widget toastBuilder(String message) => Text('toast:$message');
      Widget nextLoadingBuilder(String message) => Text('next:$message');
      Widget nextToastBuilder(String message) => Text('notice:$message');

      final original = AppModel(
        designSize: const Size(375, 812),
        title: 'Original',
        loadingBuilder: loadingBuilder,
        toastBuilder: toastBuilder,
        preferredOrientations: const [DeviceOrientation.landscapeLeft],
      );

      final retained = original.copyWith();
      expect(retained.designSize, original.designSize);
      expect(retained.title, original.title);
      expect(retained.loadingBuilder, same(original.loadingBuilder));
      expect(retained.toastBuilder, same(original.toastBuilder));
      expect(
        retained.preferredOrientations,
        same(original.preferredOrientations),
      );

      final replaced = original.copyWith(
        designSize: const Size(430, 932),
        title: 'Replaced',
        loadingBuilder: nextLoadingBuilder,
        toastBuilder: nextToastBuilder,
        preferredOrientations: const [],
      );
      expect(replaced.designSize, const Size(430, 932));
      expect(replaced.title, 'Replaced');
      expect(replaced.loadingBuilder, same(nextLoadingBuilder));
      expect(replaced.toastBuilder, same(nextToastBuilder));
      expect(replaced.preferredOrientations, isEmpty);

      final cleared = original.copyWith(
        loadingBuilder: null,
        toastBuilder: null,
      );
      expect(cleared.loadingBuilder, isNull);
      expect(cleared.toastBuilder, isNull);
    });
  });
}
