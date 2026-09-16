import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stormy_platform/stormy_platform.dart';

void main() {
  test('invalid image requests return failures without platform UI', () async {
    expect((await ImageUtils.generateThumbnail(null)).isSuccess, isFalse);
    expect(
      (await ImageUtils.generateThumbnail(Uint8List(0), maxWidth: 0)).isSuccess,
      isFalse,
    );
    expect(
      (await ImageUtils.getImageSizeFromBytes(Uint8List(0))).isSuccess,
      isFalse,
    );
  });
}
