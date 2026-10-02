import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_app_privacy/mobile_app_privacy.dart';

import 'accessibility_sensitive.dart';

class AccessibilityPage extends StatefulWidget {
  const AccessibilityPage({super.key});

  @override
  State<AccessibilityPage> createState() => _AccessibilityPageState();
}

class _AccessibilityPageState extends State<AccessibilityPage> {
  final privacy = MobileAppPrivacy();
  final controller = TextEditingController(text: 'private-probe-0');
  Timer? timer;
  int count = 0;
  String status = 'loading';

  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      controller.text = 'private-probe-${++count}';
    });
  }

  Future<void> refresh() async {
    final filtered = await privacy.isAccessibilityDataSensitive();
    if (mounted) setState(() => status = 'filtered=$filtered');
  }

  Future<void> setProtection(bool enabled) async {
    await privacy.setAccessibilityDataSensitive(enabled);
    await refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Accessibility protection')),
    body: SafeArea(
      child: Column(
        children: [
          const Text('public-probe'),
          Text(status, key: const ValueKey('filtering-state')),
          const Text('seed-probe'),
          TextField(
            key: const ValueKey('sensitive-input'),
            controller: controller,
            autofocus: true,
          ),
          const AccessibilitySensitive(child: Text('fallback-probe')),
          TextButton(
            key: const ValueKey('disable-filtering'),
            onPressed: () => setProtection(false),
            child: const Text('Disable protection'),
          ),
          TextButton(
            key: const ValueKey('enable-filtering'),
            onPressed: () => setProtection(true),
            child: const Text('Enable protection'),
          ),
        ],
      ),
    ),
  );
}
