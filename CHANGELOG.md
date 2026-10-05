## Unreleased

* Fix Android `enableOverlay` failing for colors with alpha below `0x80`,
  including transparent black, when the method channel decodes them as 32-bit integers.
* Keep Android accessibility protection active while any attached plugin instance
  requests it, including when another instance attaches with protection disabled.
* **Breaking:** Remove `AccessibilitySensitive` from the package API. The example
  app retains a version-based fallback for Android below 14, without host-state
  arguments. Applications can copy it if they accept excluding screen readers.
* Integrate the accessibility demo and its instrumentation tests into a separate
  page of the main example app, with one Dart entrypoint.

## 0.0.4

* **Breaking:** Require Flutter 3.44 and Dart 3.12 or later.
* **Breaking:** Remove CocoaPods support; iOS integration now requires Swift Package Manager.
* Migrate the iOS plugin and example to SwiftPM, including SVGKit and privacy manifests.
* Pin SVGKit to the latest `3.x` revision (September 15, 2026), including newer device models and the SwiftPM Release assertion fix.

## 0.0.1

* TODO: Describe initial release.
