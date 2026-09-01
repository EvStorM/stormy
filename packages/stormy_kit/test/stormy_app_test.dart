import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stormy_kit/stormy_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    SharedPreferencesAsyncPlatform.instance = null;
  });

  testWidgets(
    'waits for orientation initialization and uses the supplied design size',
    (tester) async {
      final orientationGate = Completer<void>();
      final orientationCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'SystemChrome.setPreferredOrientations') {
              orientationCalls.add(call);
              await orientationGate.future;
            }
            return null;
          });

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('ready')),
          ),
        ],
      );
      addTearDown(router.dispose);

      const appKey = ValueKey('stormy-app');
      final appModel = AppModel.defaults().copyWith(
        designSize: const Size(430, 932),
        preferredOrientations: const [DeviceOrientation.landscapeLeft],
      );

      await tester.pumpWidget(
        StormyApp(key: appKey, router: router, appModel: appModel),
      );

      expect(find.text('ready'), findsNothing);
      expect(orientationCalls, hasLength(1));
      expect(orientationCalls.single.arguments, const [
        'DeviceOrientation.landscapeLeft',
      ]);

      orientationGate.complete();
      await tester.pumpAndSettle();

      expect(find.text('ready'), findsOneWidget);
      expect(
        tester.widget<ScreenUtilInit>(find.byType(ScreenUtilInit)).designSize,
        const Size(430, 932),
      );

      await tester.pumpWidget(
        StormyApp(
          key: appKey,
          router: router,
          appModel: appModel.copyWith(title: 'Rebuilt'),
        ),
      );
      await tester.pump();

      expect(orientationCalls, hasLength(1));

      await tester.pumpWidget(
        StormyApp(
          key: appKey,
          router: router,
          appModel: appModel.copyWith(
            preferredOrientations: const [DeviceOrientation.landscapeRight],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(orientationCalls, hasLength(2));
      expect(orientationCalls.last.arguments, const [
        'DeviceOrientation.landscapeRight',
      ]);
    },
  );

  testWidgets('an empty orientation list delegates rotation to the system', (
    tester,
  ) async {
    final orientationCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            orientationCalls.add(call);
          }
          return null;
        });

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('system')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      StormyApp(
        router: router,
        appModel: AppModel.defaults().copyWith(preferredOrientations: const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('system'), findsOneWidget);
    expect(orientationCalls, hasLength(1));
    expect(orientationCalls.single.arguments, isEmpty);
  });
}
