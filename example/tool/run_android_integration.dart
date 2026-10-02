import 'dart:async';
import 'dart:io';

import '../test_driver/support/android_host.dart';

Future<void> main(List<String> arguments) async {
  const usage =
      'dart run tool/run_android_integration.dart --device <emulator-serial> '
      '[--flutter <path>] [--adb <path>] [--output <directory>] [--native-regressions]';
  final options = <String, String>{};
  var nativeRegressions = false;
  for (var i = 0; i < arguments.length; i++) {
    final arg = arguments[i];
    if (arg == '--help') {
      stdout.writeln(usage);
      return;
    }
    if (arg == '--native-regressions') {
      nativeRegressions = true;
      continue;
    }
    if (!['--device', '--flutter', '--adb', '--output'].contains(arg) ||
        i + 1 == arguments.length) {
      stderr.writeln(usage);
      exitCode = 64;
      return;
    }
    options[arg] = arguments[++i];
  }
  final serial = options['--device'];
  if (serial == null || serial.isEmpty) {
    stderr.writeln(usage);
    exitCode = 64;
    return;
  }
  final example = File.fromUri(Platform.script).parent.parent;
  final flutterLauncher = Platform.isWindows ? 'flutter.bat' : 'flutter';
  final flutterCandidate = File(
    '${File(Platform.resolvedExecutable).parent.parent.parent.parent.path}/$flutterLauncher',
  );
  final flutter =
      options['--flutter'] ??
      Platform.environment['FLUTTER'] ??
      (flutterCandidate.existsSync() ? flutterCandidate.path : flutterLauncher);
  final sdk =
      Platform.environment['ANDROID_SDK_ROOT'] ??
      Platform.environment['ANDROID_HOME'];
  final adbPath =
      options['--adb'] ?? (sdk == null ? 'adb' : '$sdk/platform-tools/adb');
  final adb = Adb(adbPath, serial);
  final output = Directory(
    options['--output'] ??
        '${example.path}/build/integration/$serial/${DateTime.now().toUtc().millisecondsSinceEpoch}',
  ).absolute;
  await output.create(recursive: true);
  final environment = {
    'ANDROID_SERIAL': serial,
    'PRIVACY_ADB': adbPath,
    'PRIVACY_ARTIFACTS': output.path,
  };

  Future<int> execute(
    String program,
    List<String> args,
    String logName, {
    String? cwd,
  }) async {
    stdout.writeln('Running $program ${args.join(' ')}');
    final process = await Process.start(
      program,
      args,
      workingDirectory: cwd ?? example.path,
      environment: environment,
    );
    final log = File('${output.path}/$logName').openWrite();
    final out = process.stdout.forEach((data) {
      stdout.add(data);
      log.add(data);
    });
    final err = process.stderr.forEach((data) {
      stderr.add(data);
      log.add(data);
    });
    final interrupt = ProcessSignal.sigint.watch().listen(
      (_) => process.kill(ProcessSignal.sigint),
    );
    try {
      final code = await process.exitCode.timeout(const Duration(minutes: 15));
      await Future.wait([out, err]);
      return code;
    } on TimeoutException {
      process.kill(ProcessSignal.sigint);
      await process.exitCode.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      await Future.wait([out, err]);
      rethrow;
    } finally {
      await interrupt.cancel();
      await log.close();
    }
  }

  try {
    if (await adb.shell(['getprop', 'ro.kernel.qemu']) != '1') {
      throw StateError('Select a disposable Android emulator.');
    }
    if (await adb.shell(['getprop', 'sys.boot_completed']) != '1') {
      throw StateError('Wait for the emulator to finish booting.');
    }
    exitCode = await execute(flutter, [
      'drive',
      '-d',
      serial,
      '--driver=test_driver/android_integration_driver.dart',
      '--target=integration_test/android_privacy_test.dart',
      '--android-skip-build-dependency-validation',
    ], 'flutter-drive.log');
    if (exitCode != 0 || !nativeRegressions) return;
    final abi = await adb.shell(['getprop', 'ro.product.cpu.abi']);
    final target = switch (abi) {
      'x86_64' => 'android-x64',
      'arm64-v8a' => 'android-arm64',
      _ => throw StateError('Unsupported emulator ABI: $abi'),
    };
    exitCode = await execute(flutter, [
      'build',
      'apk',
      '--debug',
      '--target=lib/main.dart',
      '--target-platform=$target',
      '--android-skip-build-dependency-validation',
    ], 'native-app-build.log');
    if (exitCode != 0) return;
    final gradleLauncher = Platform.isWindows ? 'gradlew.bat' : 'gradlew';
    exitCode = await execute(
      '${example.path}/android/$gradleLauncher',
      [
        ':app:assembleDebugAndroidTest',
        '-Ptarget=lib/main.dart',
        '-Ptarget-platform=$target',
        '-PskipDependencyChecks=true',
      ],
      'native-test-build.log',
      cwd: '${example.path}/android',
    );
    if (exitCode != 0) return;
    await adb.run([
      'install',
      '-r',
      '${example.path}/build/app/outputs/flutter-apk/app-debug.apk',
    ]);
    await adb.run([
      'install',
      '-r',
      '${example.path}/build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk',
    ]);
    final result = await runProcess(adbPath, [
      '-s',
      serial,
      'shell',
      'am',
      'instrument',
      '-w',
      '$examplePackage.test/androidx.test.runner.AndroidJUnitRunner',
    ], timeout: const Duration(minutes: 5));
    final nativeOutput = '${result.stdout}\n${result.stderr}';
    await File(
      '${output.path}/native-regressions.txt',
    ).writeAsString(nativeOutput);
    stdout.writeln(nativeOutput);
    if (result.exitCode != 0 ||
        !RegExp(r'OK \([1-9]\d* tests?\)').hasMatch(nativeOutput) ||
        nativeOutput.contains('FAILURES!!!')) {
      exitCode = 1;
      await collectDiagnostics(adb, output);
    }
  } catch (error, stack) {
    stderr.writeln('$error\n$stack');
    exitCode = 1;
  } finally {
    stdout.writeln('Artifacts: ${output.path}');
  }
}
