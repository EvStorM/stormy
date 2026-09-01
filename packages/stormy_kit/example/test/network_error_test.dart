import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stormy_kit/stormy_kit.dart';

void main() {
  test('maps a server error without calling the public internet', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..headers.contentType = ContentType.json
        ..write('{"message":"test failure"}');
      await request.response.close();
    });

    final client = StormyNetworkClient(
      config: StormyNetworkConfig(
        baseUrl: 'http://${server.address.host}:${server.port}',
        enableLog: false,
        defaultRequireToken: false,
        defaultRequireHeader: false,
      ),
    );

    await expectLater(
      client.get<Object?>('/failure'),
      throwsA(
        isA<ServerException>().having(
          (error) => error.statusCode,
          'statusCode',
          HttpStatus.internalServerError,
        ),
      ),
    );
  });
}
