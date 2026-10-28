# DayCue

A native macOS menu bar app built with Swift, SwiftUI, and AppKit.

The current scaffold provides a menu bar entry, a basic window, a launch-at-login switch, and local app packaging. Schedule management, time-block switching, Toasts, and schedule persistence are not implemented.

## Requirements

- macOS 14 or later.
- Swift 6 or later, available through a compatible Command Line Tools installation. Full Xcode is not required.

## Development

```sh
swift build
swift run DayCue
```

Use **Open DayCue…** in the menu bar to open the window. Closing the window keeps the app running; **Quit DayCue** exits it.

## Launch at Login

Use **Launch at Login** in the menu bar to enable or disable startup after user login. It remains off until enabled by the user. The switch reads the macOS login-item status each time the menu opens, including changes made in System Settings.

A dash indicates that macOS approval is required; use **Open Login Settings…** to approve it. Clicking the switch again removes the pending registration.

Configure this from the packaged app in its intended installation location. The switch is disabled for `swift run` and apps running from read-only volumes such as the DMG. No helper process or third-party dependency is required.

## Packaging

```sh
./scripts/build-app.sh
open dist/DayCue.app
./scripts/package.sh
```

The scripts create a release build, an ad hoc signed `dist/DayCue.app`, and a compressed `dist/DayCue-<version>-<architecture>.dmg`. Builds target the current Mac's architecture. Version and bundle metadata are defined in `packaging/Info.plist`.

To install, open the DMG and drag **DayCue** to **Applications**. These are local development packages, without Developer ID signing or notarization.

## Source Layout

- `Sources/DayCue/App`: application entry point and lifecycle.
- `Sources/DayCue/MenuBar`: status item and menu actions.
- `Sources/DayCue/Window`: AppKit window management and SwiftUI content.
- `packaging`: app bundle metadata.
- `scripts`: app and DMG packaging.

There are no third-party dependencies or test cases. Build outputs are ignored by Git.
