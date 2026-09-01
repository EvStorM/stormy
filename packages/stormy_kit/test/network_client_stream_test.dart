import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stormy_kit/stormy_kit.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() async {
    await server.close(force: true);
  });

  StormyNetworkClient createClient() {
    return StormyNetworkClient(
      config: StormyNetworkConfig(
        baseUrl: 'http://${server.address.host}:${server.port}',
        enableLog: false,
        defaultRequireToken: false,
        defaultRequireHeader: false,
      ),
    );
  }

  test('returns the raw response stream and reuses auth and headers', () async {
    final receivedRequest = Completer<Map<String, String>>();
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      receivedRequest.complete({
        'method': request.method,
        'query': request.uri.queryParameters['source'] ?? '',
        'authorization':
            request.headers.value(HttpHeaders.authorizationHeader) ?? '',
        'globalHeader': request.headers.value('x-global-header') ?? '',
        'requestHeader': request.headers.value('x-request-header') ?? '',
        'body': body,
      });

      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      request.response.write('data: first\n\n');
      await request.response.flush();
      request.response.write('data: second\n\n');
      await request.response.close();
    });

    final client = createClient();
    client.completeGlobalToken(token: 'secret-token');
    client.completeGlobalHeader({'X-Global-Header': 'global-value'});

    final response = await client.requestStream(
      '/events',
      method: 'POST',
      data: 'payload',
      query: {'source': 'test'},
      options: Options(headers: {'X-Request-Header': 'request-value'}),
      requireToken: true,
      requireHeader: true,
      cancelTag: 'events',
    );
    final streamText = await utf8.decoder.bind(response.data!.stream).join();
    final request = await receivedRequest.future;

    expect(response.statusCode, HttpStatus.ok);
    expect(response.requestOptions.responseType, ResponseType.stream);
    expect(streamText, 'data: first\n\ndata: second\n\n');
    expect(request['method'], 'POST');
    expect(request['query'], 'test');
    expect(request['authorization'], 'Bearer secret-token');
    expect(request['globalHeader'], 'global-value');
    expect(request['requestHeader'], 'request-value');
    expect(request['body'], 'payload');
  });

  test('maps HTTP failures through ErrorHandler', () async {
    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..headers.contentType = ContentType.json
        ..write('{"message":"broken"}');
      await request.response.close();
    });

    final client = createClient();

    await expectLater(
      client.requestStream('/failure'),
      throwsA(
        isA<ServerException>().having(
          (error) => error.statusCode,
          'statusCode',
          HttpStatus.internalServerError,
        ),
      ),
    );
  });

  test('supports cancelling a pending stream request by tag', () async {
    final requestReceived = Completer<void>();
    final releaseResponse = Completer<void>();
    server.listen((request) async {
      requestReceived.complete();
      await releaseResponse.future;
      try {
        await request.response.close();
      } on HttpException {
        // The client is expected to have closed the socket after cancellation.
      }
    });

    final client = createClient();
    final request = client.requestStream('/slow', cancelTag: 'slow-stream');
    await requestReceived.future;

    client.cancelByTag('slow-stream');

    await expectLater(request, throwsA(isA<UnknownException>()));
    releaseResponse.complete();
  });

  test(
    'maps errors emitted after response headers through ErrorHandler',
    () async {
      final client = createClient();
      client.dio.httpClientAdapter = _StreamErrorAdapter();

      final response = await client.requestStream('/stream-error');

      await expectLater(
        response.data!.stream.toList(),
        throwsA(isA<ConnectionException>()),
      );
    },
  );

  test('cancelByTag also cancels a stream after response headers', () async {
    final client = createClient();
    client.dio.httpClientAdapter = _CancelableStreamAdapter();

    final response = await client.requestStream(
      '/active-stream',
      cancelTag: 'active-stream',
    );
    final body = response.data!.stream.toList();

    client.cancelByTag('active-stream');

    await expectLater(body, throwsA(isA<UnknownException>()));
  });

  test('cancels while waiting for global auth configuration', () async {
    final client = StormyNetworkClient(
      config: StormyNetworkConfig(
        baseUrl: 'http://${server.address.host}:${server.port}',
        enableLog: false,
      ),
    );

    final request = client.requestStream(
      '/waiting-for-auth',
      cancelTag: 'waiting-for-auth',
    );
    await Future<void>.delayed(Duration.zero);

    client.cancelByTag('waiting-for-auth');

    await expectLater(request, throwsA(isA<UnknownException>()));
  });

  test('registers an external token under its cancel tag', () async {
    final client = createClient();
    client.dio.httpClientAdapter = _CancelableStreamAdapter();
    final token = CancelToken();

    final response = await client.requestStream(
      '/external-token',
      cancelToken: token,
      cancelTag: 'external-token',
    );
    final body = response.data!.stream.toList();

    client.cancelByTag('external-token');

    expect(token.isCancelled, isTrue);
    await expectLater(body, throwsA(isA<UnknownException>()));
  });

  test('releases a cancel tag when its response stream ends', () async {
    server.listen((request) async {
      request.response.write('done');
      await request.response.close();
    });
    final client = createClient();
    final token = CancelToken();

    final response = await client.requestStream(
      '/short-stream',
      cancelToken: token,
      cancelTag: 'short-stream',
    );
    await response.data!.stream.drain<void>();
    client.cancelByTag('short-stream');

    expect(token.isCancelled, isFalse);
  });
}

class _StreamErrorAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody(
      Stream<Uint8List>.error(
        DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
      ),
      HttpStatus.ok,
    );
  }

  @override
  void close({bool force = false}) {}
}

class _CancelableStreamAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final controller = StreamController<Uint8List>();
    cancelFuture?.then((_) async {
      controller.addError(
        DioException(requestOptions: options, type: DioExceptionType.cancel),
      );
      await controller.close();
    });
    return ResponseBody(controller.stream, HttpStatus.ok);
  }

  @override
  void close({bool force = false}) {}
}
