import 'package:flutter_test/flutter_test.dart';
import 'package:stormy_china_pay/stormy_china_pay.dart';

void main() {
  group('StormyChinaPay', () {
    test('should be a singleton', () {
      final instance1 = StormyChinaPay();
      final instance2 = StormyChinaPay();
      expect(identical(instance1, instance2), isTrue);
    });
  });

  group('WechatSDK', () {
    test('should be a singleton', () {
      final instance1 = WechatSDK();
      final instance2 = WechatSDK();
      expect(identical(instance1, instance2), isTrue);
    });
  });

  group('AlipaySDK', () {
    test('should be a singleton', () {
      final instance1 = AlipaySDK();
      final instance2 = AlipaySDK();
      expect(identical(instance1, instance2), isTrue);
    });
  });
}
