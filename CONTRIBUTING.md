# Contributing to Mac Autoruns Lite

Thanks for helping improve Mac Autoruns Lite.

## Project principles

Please keep contributions aligned with these goals:

- Native macOS behavior using Swift / SwiftUI / AppKit where appropriate
- Small, focused scope
- Conservative system modification
- Reversible actions whenever possible
- No telemetry or analytics
- No hidden background services
- No automatic `sudo` or password storage
- No SIP modification

## Development setup

Requirements:

- macOS 14+
- Xcode

Open the project:

```bash
open AutorunsLite.xcodeproj
```

Build from the command line:

```bash
xcodebuild \
  -project AutorunsLite.xcodeproj \
  -scheme AutorunsLite \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run tests:

```bash
xcodebuild \
  -project AutorunsLite.xcodeproj \
  -scheme AutorunsLite \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## Safety-related changes

Changes involving `launchctl`, Safe Action classification, startup-item state, file removal, elevated privileges, or system paths should include tests and should default to the safer behavior when classification is uncertain.

If an item cannot be confidently classified as safe, prefer `Review Required` instead of automatically modifying it.

## Pull requests

Please include:

- A concise explanation of the change
- Why the behavior is safe
- Tests for non-trivial logic
- Screenshots for visible UI changes when practical

Avoid unrelated refactors in the same change.
