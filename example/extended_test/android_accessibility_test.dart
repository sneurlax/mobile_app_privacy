import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_support/privacy_app.dart';

import 'support/host_binding.dart';

void main() {
  final binding = HostBinding();
  late int sdk;

  bool secret(String text) =>
      text.contains('seed-probe') || text.contains('private-probe');
  String events(Map<String, dynamic> state, String key) =>
      (state[key] as List).join('\n');

  Future<void> checkAccessibility(
    WidgetTester tester,
    String phase,
    bool protected,
  ) async {
    await waitNative(
      '$phase: tool reads the real Flutter view tree',
      (s) =>
          (s['toolTree'] as String).contains('public-probe') &&
          (s['toolTree'] as String).contains('seed-probe') &&
          (s['toolTree'] as String).contains('private-probe') &&
          ((s['toolTree'] as String).contains('fallback-probe') == (sdk >= 34)),
      tester: tester,
    );
    await tester.pump(const Duration(milliseconds: 800));
    await probe.invokeMethod<void>('clearEvents');
    await waitNative(
      '$phase: tool receives fresh input events',
      (s) => events(s, 'toolEvents').contains('private-probe'),
      tester: tester,
    );
    if (!protected) {
      await waitNative(
        '$phase: non-tool positive control',
        (s) =>
            secret(s['nonToolTree'] as String) &&
            events(s, 'nonToolEvents').contains('private-probe'),
        tester: tester,
      );
    }
    Map<String, dynamic> state = {};
    for (var sample = 0; sample < 10; sample++) {
      state = await snapshot();
      final toolTree = state['toolTree'] as String;
      final otherTree = state['nonToolTree'] as String;
      expect(toolTree, contains('seed-probe'), reason: phase);
      expect(toolTree.contains('fallback-probe'), sdk >= 34, reason: phase);
      expect(
        otherTree.contains('fallback-probe'),
        sdk >= 34 && !protected,
        reason: phase,
      );
      if (protected) {
        expect(
          secret(otherTree),
          isFalse,
          reason: '$phase: non-tool node leak',
        );
        expect(
          secret(events(state, 'nonToolEvents')),
          isFalse,
          reason: '$phase: event leak',
        );
        expect(
          events(state, 'nonToolEvents'),
          isNot(contains('fallback-probe')),
        );
      } else {
        expect(otherTree, contains('public-probe'), reason: phase);
        expect(otherTree, contains('seed-probe'), reason: phase);
        expect(otherTree, contains('private-probe'), reason: phase);
      }
      if (sdk < 34) {
        expect(events(state, 'toolEvents'), isNot(contains('fallback-probe')));
        expect(
          events(state, 'nonToolEvents'),
          isNot(contains('fallback-probe')),
        );
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    (binding.reportData!['phases'] as List).add({
      'phase': phase,
      'protected': protected,
      ...state,
    });
  }

  Future<void> prepare() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Run this suite on an Android emulator.');
    }
    final host = await binding.hostCommand('ready');
    sdk = (await snapshot())['sdkInt'] as int;
    expect(sdk, host['sdkInt']);
    binding.reportData ??= {
      'device': host['device'],
      'sdkInt': sdk,
      'phases': <Object>[],
    };
  }

  // Keep setup/cleanup here: setUpAll/tearDown failures can evade driver results.
  void privacyTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await prepare();
        await body(tester);
      } finally {
        await cleanup(tester);
      }
    });
  }

  privacyTest(
    'real app navigation, native filtering, and legacy semantics fallback',
    (tester) async {
      await openExample(tester);
      await waitNative(
        'both real accessibility services connected',
        (s) => s['toolConnected'] == true && s['nonToolConnected'] == true,
        tester: tester,
      );

      expect(await privacy.isAccessibilityDataSensitive(), sdk >= 34);
      await tester.tap(find.byKey(const ValueKey('open-accessibility')));
      await waitFor(tester, find.text('filtered=${sdk >= 34}'));
      await checkAccessibility(tester, 'startup', sdk >= 34);

      await tester.tap(find.byKey(const ValueKey('disable-filtering')));
      await waitFor(tester, find.text('filtered=false'));
      expect(await privacy.isAccessibilityDataSensitive(), isFalse);
      await tester.enterText(
        find.byKey(const ValueKey('sensitive-input')),
        'private-probe-entered',
      );
      await checkAccessibility(tester, 'disabled', false);

      await tester.tap(find.byKey(const ValueKey('enable-filtering')));
      await waitFor(tester, find.text('filtered=${sdk >= 34}'));
      expect(await privacy.isAccessibilityDataSensitive(), sdk >= 34);
      await checkAccessibility(tester, 're-enabled', sdk >= 34);
      await tester.pageBack();
      await waitFor(tester, find.byKey(const ValueKey('open-accessibility')));
    },
  );

  privacyTest(
    'ADB background and resume exercise the real app lifecycle overlay',
    (tester) async {
      await openExample(tester);
      final children = (await snapshot())['decorChildren'] as int;
      try {
        await binding.hostCommand('background');
        await waitNative(
          'background lifecycle installed the native overlay',
          (s) => s['decorChildren'] == children + 1,
        );
      } finally {
        await binding.hostCommand('resume');
      }
      await waitNative(
        'resume removed the native overlay',
        (s) => s['decorChildren'] == children,
        tester: tester,
      );
      expect(await privacy.isAccessibilityDataSensitive(), sdk >= 34);
    },
  );
}
