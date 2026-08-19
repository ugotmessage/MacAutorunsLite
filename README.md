# Mac Autoruns Lite

A lightweight native macOS startup manager with orphan detection and safe, reversible actions.

Mac Autoruns Lite helps you inspect startup items without turning into a full system-cleaner suite. It covers traditional `launchd` plists and, in v0.2, modern macOS startup sources for display and research.

> This project is not affiliated with Microsoft or Sysinternals Autoruns.

## Features

- Inspect User LaunchAgents, System LaunchAgents, LaunchDaemons, Login Items, Background Tasks, and SMAppService entries
- Detect orphaned startup entries whose executable no longer exists
- View load state, recommendation, and startup metadata
- Start / stop and enable / disable supported items
- Conservative **Safe Action** classification
- Preview changes before applying them
- Snapshot-based rollback for Safe Action operations
- Advanced Move to Trash for leftover User LaunchAgents
- Built-in Service Research browser
- Search and filter startup items
- Configurable search keywords and query templates
- Optional embedded research browser; system browser is the default
- Local per-item research notes
- View plist details and reveal files in Finder
- System / Light / Dark appearance modes
- Native Swift + SwiftUI macOS app
- No Electron
- No telemetry
- No background daemon

## Scan scope

Supported **Startup Sources** in v0.2.0:

- **User LaunchAgent** — `~/Library/LaunchAgents`
- **System LaunchAgent** — `/Library/LaunchAgents`
- **LaunchDaemon** — `/Library/LaunchDaemons`
- **Login Item** — Open at Login (LSSharedFileList) and `App.app/Contents/Library/LoginItems`
- **SMAppService** — in-bundle `Contents/Library/LaunchAgents` and `Contents/Library/LaunchDaemons`
- **Background Task** — items from `sfltool dumpbtm` when readable without sudo

XPC services (`Contents/XPCServices`) are **not** listed as a startup type. They appear as related helpers on the parent App.

Traditional launchd items still support Start / Stop / Enable / Disable and conservative Safe Action. Modern sources in v0.2 are **display and research only**; manage them in **System Settings → General → Login Items & Extensions**. The app never uses `sudo`.

Opening the app scans **user** sources only (`~/Library/LaunchAgents`, Login Items, and in-bundle helpers). System LaunchAgents, LaunchDaemons, and Background Task Management are loaded only after you click **載入系統啟動項目**; macOS may then ask for an administrator password. That choice is not remembered across launches.

If Background Task Management cannot be read (dumpbtm often needs root, and the `.btm` database needs Full Disk Access), Login Items and in-bundle helpers still appear, with status shown as unknown.

A launchd service that is loaded but has no matching plist in the traditional directories may still appear if Background Task Management lists it.

## Understanding startup states

Mac Autoruns Lite separates **runtime status** from **cleanup recommendations**.

- **Loaded** means launchd has loaded the job. It does **not** necessarily mean the process is running right now. launchd may be waiting for RunAtLoad, KeepAlive, a timer, or a socket.
- **Unloaded** means the plist exists but the job is not currently registered in the domain. That is **not** the same as unused, and it is **not** a reason to delete the item.
- **Disabled** means launchd has marked the job so it will not autoload until it is enabled again.
- **Orphaned** means the plist still exists but the executable it points to is missing. That is worth reviewing; it is still not always safe to delete.

## Safety model

Mac Autoruns Lite is intentionally conservative.

Automatic Safe Actions are limited to high-confidence cases such as orphaned third-party **User LaunchAgents** whose executable no longer exists. Apple/system items, LaunchDaemons, System LaunchAgents, Login Items, Background Tasks, SMAppService entries, unknown sources, KeepAlive jobs, and items that may still belong to installed apps are excluded from automatic handling and require manual review.

Safe Action does **not** delete plist files. It prefers reversible `launchctl` operations and stores a snapshot so the previous state can be restored where possible.

Moving a plist to Trash is a separate advanced action, limited to `~/Library/LaunchAgents`.

## Privacy

Core startup inspection and management is local.

Network access only occurs when the user explicitly uses Service Research.

Service Research is opt-in. Mac Autoruns Lite does not automatically upload startup-item information. When the user explicitly starts Service Research, the selected service label and search keywords are sent to the configured search engine.

## Service Research

For a selected service such as:

```text
com.adobe.acc.installer.v2
```

Mac Autoruns Lite can quickly search:

```text
"com.adobe.acc.installer.v2" LaunchDaemon macOS
```

Search results are for reference only. They never change SafetyClassifier, recommendations, Safe Action, or Move to Trash.

Research notes are stored locally on this Mac and are not uploaded.

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

v0.2.0 lists modern Login Items, Background Tasks, and SMAppService helpers for inspection and research. It does not enable, disable, or delete those items; use System Settings instead.

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
