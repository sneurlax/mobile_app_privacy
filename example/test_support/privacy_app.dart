import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_privacy/mobile_app_privacy.dart';
import 'package:mobile_app_privacy_example/main.dart' as app;

const probe = MethodChannel('mobile_app_privacy_example/test');
final privacy = MobileAppPrivacy();

Future<int> androidSdk() async {
  if (!Platform.isAndroid) throw UnsupportedError('Android required');
  return (await snapshot())['sdkInt'] as int;
}

Future<Map<String, dynamic>> snapshot() async =>
    (await probe.invokeMapMethod<String, dynamic>('snapshot'))!;

Future<Map<String, dynamic>> waitNative(
  String description,
  bool Function(Map<String, dynamic>) predicate, {
  WidgetTester? tester,
}) async {
  final timer = Stopwatch()..start();
  Map<String, dynamic> latest = {};
  while (timer.elapsed < const Duration(seconds: 15)) {
    latest = await snapshot();
    if (predicate(latest)) return latest;
    if (tester == null) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    } else {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  fail('Timed out: $description. Last native snapshot: $latest');
}

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final timer = Stopwatch()..start();
  while (finder.evaluate().isEmpty &&
      timer.elapsed < const Duration(seconds: 15)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

Future<void> openExample(WidgetTester tester) async {
  app.main();
  await waitFor(tester, find.textContaining('Running on: Android'));
}

Future<void> cleanup(WidgetTester tester) async {
  await privacy.disableOverlay();
  await privacy.setFlagSecure(false);
  await privacy.setAccessibilityDataSensitive(true);
  await tester.pumpWidget(const SizedBox.shrink());
}
