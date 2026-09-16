import 'package:flutter_test/flutter_test.dart';
import 'package:stormy_store_pay/stormy_store_pay.dart';

void main() {
  test(
    'disposing the default instance permits a fresh instance only',
    () async {
      final old = StorePayManager.instance;
      await old.dispose();
      expect(StorePayManager.instance, isNot(same(old)));
      expect(() => old.initialize(), throwsStateError);
      await StorePayManager.instance.dispose();
    },
  );
}
