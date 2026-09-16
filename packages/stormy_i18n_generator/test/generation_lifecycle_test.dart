import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:stormy_i18n_generator/src/generator/serial_generation_queue.dart';

void main() {
  test(
    'changes during generation are coalesced without overlapping runs',
    () async {
      var active = 0;
      var runs = 0;
      final first = Completer<void>();
      final entered = Completer<void>();
      final queue = SerialGenerationQueue(() async {
        expect(++active, 1);
        runs++;
        if (runs == 1) {
          entered.complete();
          await first.future;
        }
        active--;
      });
      final pending = queue.request();
      await entered.future;
      final edits = List.generate(10, (_) => queue.request());
      first.complete();
      await Future.wait([pending, ...edits]);
      expect(runs, 2);
      await queue.request();
      expect(runs, 3);
    },
  );

  test('failed generation can be retried', () async {
    var fail = true;
    final queue = SerialGenerationQueue(() async {
      if (fail) throw StateError('failed');
    });
    await expectLater(queue.request(), throwsStateError);
    fail = false;
    await queue.request();
  });

  test('CLI propagates gen-l10n exit code', () async {
    final root = Directory('../../temp/reliability').absolute;
    root.createSync(recursive: true);
    final fixture = root.createTempSync('generator_');
    addTearDown(() => fixture.deleteSync(recursive: true));
    File('${fixture.path}/stormy_i18n.yaml').writeAsStringSync('''
source_dir: lib/l10n/src
locales: [en, zh]
''');
    Directory('${fixture.path}/lib/l10n/src').createSync(recursive: true);
    File('${fixture.path}/lib/l10n/src/messages.dart').writeAsStringSync('''
class Messages { static const hello = I18nItem(en: 'Hello', zh: '你好'); }
''');
    final fakeFlutter = File('${fixture.path}/flutter');
    fakeFlutter.writeAsStringSync('#!/bin/sh\nexit 42\n');
    final permission = await Process.run('chmod', ['+x', fakeFlutter.path]);
    expect(permission.exitCode, 0);
    final result = await Process.run(Platform.resolvedExecutable, [
      '--packages=${File('../../.dart_tool/package_config.json').absolute.path}',
      File('bin/stormy_i18n_generator.dart').absolute.path,
      '--flutter=${fakeFlutter.path}',
      'gen',
    ], workingDirectory: fixture.path);
    expect(result.exitCode, 42, reason: '${result.stdout}\n${result.stderr}');
  }, skip: Platform.isWindows ? 'POSIX executable fixture' : false);
}
