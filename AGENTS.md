# Project

- Build a macOS-only menu bar time-block app within the agreed MVP scope.
- Use Swift, SwiftUI for Schedule, and AppKit for the menu bar, and UserNotifications for reminders.
- Build with SwiftPM and package `.app` bundles with a script; require only Command Line Tools and the macOS SDK.
- Store schedules as local JSON. Prefer system frameworks.
- For keyboard, window-close, or quit changes, read local `docs/interaction.md` when available.

# Language

- Communicate in Simplified Chinese by default.
- Use English for repository content, commit messages, and MR metadata. Only `README.md` and i18n resources may contain Chinese.
- Keep UI text, errors, logs, and CLI output in concise English. Do not add i18n solely for Chinese text.

# Documentation

- Define each rule once; reference it elsewhere.
- Specify valid inputs, allowed state changes, and observable results.
- Keep AI-written product and technical design documents local and untracked. Repository rules and development instructions may be tracked.

# Code

- Implement directly; extract interfaces or shared components only for concrete replacement or reuse needs.
- Use named types; convert dynamic input to concrete types at system and form boundaries.
- Keep schedule calculation and validation independent of UI code.
- Do not write code comments. Required tool directives, including `swift-tools-version`, and tool-generated comments are exempt.
- Change generators or their inputs, not generated files.
- Do not track build outputs, caches, logs, or app bundles.

# Verification

- Add tests only when explicitly requested.
- Run `swift build` after Swift code changes; run relevant existing tests after behavior or test changes.
- Verify UI changes on macOS. Report completed checks and remaining manual checks before committing.

