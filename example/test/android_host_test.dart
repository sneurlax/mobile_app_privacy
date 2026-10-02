import 'package:flutter_test/flutter_test.dart';

import '../test_driver/support/android_host.dart';

void main() {
  test(
    'probe setup preserves existing services and restores exact settings',
    () async {
      final values = <String, String>{
        'enabled_accessibility_services': 'other.package/.Reader',
        'accessibility_enabled': '0',
      };
      final original = Map<String, String>.of(values);
      Future<String> shell(List<String> args) async {
        final key = args[3];
        if (args[1] == 'get') return values[key] ?? 'null';
        if (args[1] == 'delete') {
          values.remove(key);
        } else {
          values[key] = args[4];
        }
        return '';
      }

      final settings = AccessibilitySettings(shell);
      await settings.enableProbes();
      expect(
        values['enabled_accessibility_services'],
        startsWith('other.package/.Reader:'),
      );
      expect(
        values['enabled_accessibility_services'],
        contains('.NonToolProbeService'),
      );
      expect(values['accessibility_enabled'], '1');
      await settings.restore();
      expect(values, original);
      await settings.restore();
      expect(values, original);
    },
  );

  test('partial setup failure restores previously absent settings', () async {
    final values = <String, String>{};
    Future<String> shell(List<String> args) async {
      final key = args[3];
      if (args[1] == 'get') return values[key] ?? 'null';
      if (args[1] == 'put' && key == 'accessibility_enabled') {
        throw StateError('ADB failure');
      }
      if (args[1] == 'delete') {
        values.remove(key);
      } else {
        values[key] = args[4];
      }
      return '';
    }

    final settings = AccessibilitySettings(shell);
    await expectLater(settings.enableProbes(), throwsStateError);
    await settings.restore();
    expect(values, isEmpty);
  });

  test(
    'one failed restore does not prevent restoring the other setting and can be retried',
    () async {
      final values = <String, String>{
        'enabled_accessibility_services': 'other/.Reader',
        'accessibility_enabled': '0',
      };
      final original = Map<String, String>.of(values);
      var failRestore = false;
      Future<String> shell(List<String> args) async {
        final key = args[3];
        if (args[1] == 'get') return values[key] ?? 'null';
        if (failRestore && key == 'enabled_accessibility_services') {
          throw StateError('temporary disconnect');
        }
        values[key] = args[4];
        return '';
      }

      final settings = AccessibilitySettings(shell);
      await settings.enableProbes();
      failRestore = true;
      await expectLater(settings.restore(), throwsStateError);
      expect(values['accessibility_enabled'], '0');
      failRestore = false;
      await settings.restore();
      expect(values, original);
    },
  );
}
