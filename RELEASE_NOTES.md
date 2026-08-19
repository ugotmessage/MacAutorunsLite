# MacAutorunsLite v0.1.0

First public release of MacAutorunsLite, a lightweight native macOS viewer for traditional `launchd` startup items.

## Highlights

- Scan User LaunchAgents, System LaunchAgents, and LaunchDaemons
- Loaded / Unloaded / Disabled / Orphaned status
- Built-in status help explaining what each state means
- Recommendation classification for leftover items
- Conservative Safe Action with preview
- Undo via snapshot-based rollback
- Advanced Move to Trash for leftover User LaunchAgents
- Service Research for looking up a selected service
- Custom search template and keywords
- System / Light / Dark appearance
- Requires macOS 14+

## Current limitations

This release does **not** fully support:

- SMAppService
- Modern Login Items
- Background Tasks

The scan currently covers traditional launchd plist files in:

- `~/Library/LaunchAgents`
- `/Library/LaunchAgents`
- `/Library/LaunchDaemons`

## Unsigned build

This GitHub Release includes an **unsigned** macOS `.app`.

- It is **not** signed with an Apple Developer ID
- It is **not** notarized
- macOS Gatekeeper will likely block or warn on first open

To open an unsigned build, Control-click the app and choose **Open**, then confirm. Do not expect this build to pass Gatekeeper as a signed, notarized app.

Safe Action never deletes files. Moving a plist to Trash is a separate advanced action, limited to `~/Library/LaunchAgents`.
