import 'dart:async';
import 'dart:convert';
import 'dart:io';

const examplePackage = 'com.cypherstack.mobile_app_privacy_example';
typedef Shell = Future<String> Function(List<String> arguments);

Future<ProcessResult> runProcess(
  String executable,
  List<String> arguments, {
  bool binary = false,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final process = await Process.start(executable, arguments);
  final output = process.stdout.fold<List<int>>(
    [],
    (all, chunk) => all..addAll(chunk),
  );
  final errors = process.stderr.transform(utf8.decoder).join();
  int code;
  try {
    code = await process.exitCode.timeout(timeout);
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    await process.exitCode;
    await output;
    await errors;
    rethrow;
  }
  final bytes = await output;
  return ProcessResult(
    process.pid,
    code,
    binary ? bytes : utf8.decode(bytes, allowMalformed: true),
    await errors,
  );
}

class Adb {
  Adb(this.executable, this.serial);
  final String executable;
  final String serial;

  Future<ProcessResult> run(
    List<String> arguments, {
    bool binary = false,
  }) async {
    final args = ['-s', serial, ...arguments];
    final result = await runProcess(executable, args, binary: binary);
    if (result.exitCode != 0) {
      throw ProcessException(
        executable,
        args,
        '${result.stderr}',
        result.exitCode,
      );
    }
    return result;
  }

  Future<String> shell(List<String> arguments) async {
    final command = arguments
        .map((s) => "'${s.replaceAll("'", "'\\''")}'")
        .join(' ');
    return '${(await run(['shell', command])).stdout}'.trim();
  }
}

class AccessibilitySettings {
  AccessibilitySettings(this.shell);
  final Shell shell;
  final _previous = <String, String>{};
  static const keys = [
    'enabled_accessibility_services',
    'accessibility_enabled',
  ];

  Future<void> enableProbes() async {
    if (_previous.isNotEmpty) throw StateError('Settings already captured');
    final snapshot = <String, String>{};
    for (final key in keys) {
      snapshot[key] = await shell(['settings', 'get', 'secure', key]);
    }
    _previous.addAll(snapshot);
    final original = snapshot[keys.first]!;
    final services = <String>{
      if (original != 'null' && original.isNotEmpty) ...original.split(':'),
      '$examplePackage/.ToolProbeService',
      '$examplePackage/.NonToolProbeService',
    };
    await shell(['settings', 'put', 'secure', keys.first, services.join(':')]);
    await shell(['settings', 'put', 'secure', keys.last, '1']);
  }

  Future<void> restore() async {
    final errors = <Object>[];
    for (final entry in _previous.entries.toList()) {
      try {
        await shell(
          entry.value == 'null'
              ? ['settings', 'delete', 'secure', entry.key]
              : ['settings', 'put', 'secure', entry.key, entry.value],
        );
        _previous.remove(entry.key);
      } catch (error) {
        errors.add(error);
      }
    }
    if (errors.isNotEmpty) {
      throw StateError('Could not restore emulator settings: $errors');
    }
  }
}

Future<void> collectDiagnostics(Adb adb, Directory output) async {
  final commands = <String, List<String>>{
    'logcat.txt': ['logcat', '-d', '-t', '1500'],
    'window.txt': ['shell', 'dumpsys window'],
    'accessibility.txt': ['shell', 'dumpsys accessibility'],
    'screen.png': ['exec-out', 'screencap', '-p'],
  };
  for (final entry in commands.entries) {
    try {
      final binary = entry.key.endsWith('.png');
      final result = await adb.run(entry.value, binary: binary);
      final file = File('${output.path}/${entry.key}');
      if (binary) {
        await file.writeAsBytes(result.stdout as List<int>);
      } else {
        await file.writeAsString('${result.stdout}');
      }
    } catch (error) {
      await File(
        '${output.path}/diagnostic-errors.txt',
      ).writeAsString('${entry.key}: $error\n', mode: FileMode.append);
    }
  }
}
