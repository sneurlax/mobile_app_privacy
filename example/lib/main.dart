import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_app_privacy/mobile_app_privacy.dart';

import 'accessibility_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  String _platformVersion = 'Unknown';
  final _mobileAppPrivacyPlugin = MobileAppPrivacy();

  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion =
          await _mobileAppPrivacyPlugin.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      _mobileAppPrivacyPlugin.disableOverlay();
    } else {
      _mobileAppPrivacyPlugin.enableOverlay(blurInsteadOfColor: true);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initPlatformState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {'/accessibility': (_) => const AccessibilityPage()},
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Running on: $_platformVersion\n',
                key: const ValueKey('platform-version'),
              ),
              Builder(
                builder: (context) => TextButton(
                  key: const ValueKey('open-accessibility'),
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/accessibility'),
                  child: const Text('Accessibility protection'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
