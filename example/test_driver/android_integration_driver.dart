import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart';

import 'support/android_host.dart';

Future<void> main() async {
  final serial = Platform.environment['ANDROID_SERIAL'];
  if (serial == null || serial.isEmpty) {
    throw StateError('Use tool/run_android_integration.dart --device <serial>');
  }
  final adb = Adb(Platform.environment['PRIVACY_ADB'] ?? 'adb', serial);
  final output = Directory(Platform.environment['PRIVACY_ARTIFACTS']!);
  await output.create(recursive: true);
  final settings = AccessibilitySettings(adb.shell);
  FlutterDriver? driver;
  var passed = false;
  var stopped = false;
  Future<void>? cleanupFuture;
  Future<void> cleanup() => cleanupFuture ??= () async {
    if (!passed) await collectDiagnostics(adb, output);
    try {
      await settings.restore();
      await File(
        '${output.path}/cleanup.txt',
      ).writeAsString('Accessibility settings restored.\n');
    } catch (error) {
      passed = false;
      stderr.writeln(error);
      await File('${output.path}/cleanup.txt').writeAsString('$error\n');
    }
    stopped = true;
    try {
      await driver?.close();
    } catch (error) {
      passed = false;
      stderr.writeln('Driver cleanup failed: $error');
    }
  }();
  final interrupt = ProcessSignal.sigint.watch().listen((_) async {
    await cleanup();
    exit(130);
  });
  try {
    if (await adb.shell(['getprop', 'ro.kernel.qemu']) != '1') {
      throw StateError('This suite requires a disposable Android emulator.');
    }
    final sdk = int.parse(await adb.shell(['getprop', 'ro.build.version.sdk']));
    await settings.enableProbes();
    driver = await FlutterDriver.connect();
    final connected = driver;
    await () async {
      while (!stopped) {
        final command =
            jsonDecode(
                  await connected.requestData(
                    'host:next',
                    timeout: const Duration(seconds: 20),
                  ),
                )
                as Map<String, dynamic>;
        if (command['done'] == true) {
          if ((command['testCount'] as int? ?? 0) == 0) {
            throw StateError('The app completed without running widget tests.');
          }
          break;
        }
        if (command['id'] == null) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          continue;
        }
        final reply = <String, dynamic>{'id': command['id']};
        try {
          switch (command['command']) {
            case 'ready':
              reply['data'] = {'sdkInt': sdk, 'device': serial};
            case 'background':
              await adb.shell(['input', 'keyevent', 'KEYCODE_HOME']);
              reply['data'] = <String, dynamic>{};
            case 'resume':
              await adb.shell([
                'am',
                'start',
                '-n',
                '$examplePackage/.MainActivity',
              ]);
              reply['data'] = <String, dynamic>{};
            default:
              throw StateError('Unsupported host command: $command');
          }
        } catch (error) {
          reply['error'] = '$error';
        }
        await connected.requestData(
          'host:reply:${jsonEncode(reply)}',
          timeout: const Duration(seconds: 20),
        );
      }
    }().timeout(const Duration(minutes: 8));
    final response = Response.fromJson(await connected.requestData(null));
    passed = response.allTestsPassed;
    await File('${output.path}/results.json').writeAsString(response.toJson());
    if (!passed) stderr.writeln(response.formattedFailureDetails);
  } catch (error, stack) {
    passed = false;
    stopped = true;
    stderr.writeln('$error\n$stack');
    await File(
      '${output.path}/driver-error.txt',
    ).writeAsString('$error\n$stack');
  } finally {
    await cleanup();
    await interrupt.cancel();
  }
  stdout.writeln(
    passed
        ? 'Android integration tests passed.'
        : 'Android integration tests failed.',
  );
  exitCode = passed ? 0 : 1;
}
