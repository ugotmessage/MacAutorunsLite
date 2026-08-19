# Mac Autoruns Lite

A lightweight native macOS startup manager with orphan detection and safe, reversible actions.

Mac Autoruns Lite helps you inspect and manage `launchd` startup items without turning into a full system-cleaner suite. It focuses on LaunchAgents, LaunchDaemons, startup leftovers, and conservative actions that are easy to understand and reverse.

> This project is not affiliated with Microsoft or Sysinternals Autoruns.

## Features

- Inspect User LaunchAgents, System LaunchAgents, and LaunchDaemons
- Detect orphaned startup entries whose executable no longer exists
- View load state and startup metadata
- Start / stop and enable / disable supported items
- Conservative **Safe Action** classification
- Preview changes before applying them
- Snapshot-based rollback for Safe Action operations
- Search and filter startup items
- View plist details and reveal files in Finder
- System / Light / Dark appearance modes
- Native Swift + SwiftUI macOS app
- No Electron
- No telemetry
- No background daemon

## Safety model

Mac Autoruns Lite is intentionally conservative.

Automatic Safe Actions are limited to high-confidence cases such as orphaned third-party **User LaunchAgents** whose executable no longer exists. Apple/system items, LaunchDaemons, System LaunchAgents, unknown sources, KeepAlive jobs, and items that may still belong to installed apps are excluded from automatic handling and require manual review.

Safe Action does **not** delete plist files. It prefers reversible `launchctl` operations and stores a snapshot so the previous state can be restored where possible.

## Why App Sandbox is disabled

The app needs to inspect locations such as:

```text
~/Library/LaunchAgents
/Library/LaunchAgents
/Library/LaunchDaemons
```

and interact with `/bin/launchctl`. These tasks are not practical inside the normal App Sandbox restrictions.

Mac Autoruns Lite does not require network access for its core functionality and does not include telemetry or analytics.

## Requirements

- macOS 14 or later
- Xcode for building from source

## Build from source

Clone the repository:

```bash
git clone https://github.com/ugotmessage/MacAutorunsLite.git
cd MacAutorunsLite
```

Open the Xcode project:

```bash
open AutorunsLite.xcodeproj
```

Then build and run the `AutorunsLite` scheme from Xcode.

For command-line CI-style builds without code signing:

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

## Current scope

Mac Autoruns Lite currently focuses on `launchd` startup entries. macOS Login Items are intentionally left to System Settings rather than being modified through unsupported or fragile workarounds.

The app also avoids automatic `sudo`, password storage, SIP modification, and automatic deletion of startup files.

## Roadmap

- Improve startup-item grouping and visual hierarchy
- Add screenshots to the README
- Improve orphan/vendor detection using local metadata
- Expand Safe Action diagnostics
- Add release packaging and notarization workflow
- Continue improving automated tests

## Contributing

Issues and pull requests are welcome. Please keep changes aligned with the project's core goals: native macOS behavior, small scope, conservative system modification, and reversible actions.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development notes.

## License

MIT License. See [LICENSE](LICENSE).
