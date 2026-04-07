import 'package:flutter_test/flutter_test.dart';
import 'package:stormy_kit/stormy_kit.dart';

void main() {
  test('Network Call Test', () async {
    final client = StormyNetworkClient(
      config: StormyNetworkConfig(
        parsingConfig: ResponseParsingConfig(messageKey: "message", successCode: 200),
        baseUrl: "https://qiaopai.wzglob.top/api/open",
        enableLog: true,
        defaultRequireToken: false,
        defaultRequireHeader: false,
      )
    );

    try {
      final res = await client.get(
        '/style-background-configs',
        requireToken: false,
        parser: const DirectParser(),
      );
      print("SUCCESS RESPONSE: $res");
    } catch (e, st) {
      print("ERROR CAUGHT: ${e.runtimeType}: $e");
      print("STACK TRACE:\n$st");
      rethrow;
    }
  });
}
