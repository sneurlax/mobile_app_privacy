# mobile_app_privacy_example

Run `flutter run` to open the example app. Its home page shows the platform
version and demonstrates privacy overlays when the app leaves the foreground.
Choose **Accessibility protection** to open a separate page with sample content
and native filtering controls. Android instrumentation tests navigate to this
same page to check filtering in both Flutter activity embeddings, rather than
building a separate accessibility app.

`lib/accessibility_sensitive.dart` is an optional example-only widget. It queries
the Android SDK version through an example-only platform channel once per mount.
Below Android 14 (SDK 34), it excludes the wrapped subtree's semantics, including
screen-reader access. On Android 14+, it leaves semantics available regardless of
the native filtering toggle. It does nothing on other platforms. While the SDK
lookup is pending or fails, it keeps semantics excluded on Android.

Use it by wrapping sensitive content; no synchronized host state is needed:

```dart
AccessibilitySensitive(child: Text('example secret'))
```

This is an application policy choice, not a requirement for using the plugin.
Applications copying the widget must also provide its SDK lookup channel (see
`android/app/src/main/kotlin/com/cypherstack/mobile_app_privacy_example/ExamplePlatform.kt`)
or use their existing device-information API.

Run widget tests from this directory with `flutter test test`. To run Android
instrumentation tests, start a disposable API 33 or 34 emulator, then:

```sh
flutter build apk --debug --target lib/main.dart --target-platform android-x64 --android-skip-build-dependency-validation
cd android
./gradlew :app:connectedDebugAndroidTest -Ptarget=lib/main.dart -Ptarget-platform=android-x64 -PskipDependencyChecks=true
```

From `example/`, run standard tests on API 33 and 34:

```sh
flutter test integration_test -d <emulator-serial>
```

For actual service events and ADB lifecycle checks, use a disposable emulator:

```sh
dart run tool/run_android_integration.dart --device <device-id> --native-regressions
```

`extended_test/` requires this driver; `--native-regressions` also runs the existing activity/engine tests.
