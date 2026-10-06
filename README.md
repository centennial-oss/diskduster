# DiskDuster™

Dust off your Mac's drive and reclaim space.

DiskDuster is a free, open source macOS app that finds caches, logs, developer leftovers and other files that are safe to remove, shows how much space each one uses, and cleans only what you choose.

DiskDuster is distributed through [this project's releases](https://github.com/centennial-oss/diskduster/releases) as a notarized app. It is not available in the Mac App Store, because the App Store requires sandboxing, and a sandboxed app cannot see most of the places where reclaimable files live.

## Features

- **Fast, accurate scan** — Measures real disk usage (allocated blocks, like `du`), never follows symlinks, and counts hard-linked files once.
- **Organized by category** — Caches, App Data Caches, Logs, Developer files (Xcode DerivedData, device support, simulator caches, npm and Gradle caches), Trash, System Caches and System Logs.
- **Friendly names** — Cache folders named after bundle identifiers are shown with the app's name and icon.
- **You choose** — Safe items are selected by default; anything slow or costly to rebuild (like Xcode Archives or iOS Device Support) is listed but left unselected.
- **Recoverable by default** — Your files are moved to the Trash unless you choose permanent deletion in Settings.
- **System locations are optional** — Cleaning system items asks for an administrator password once per clean. If none are selected, or system locations are turned off, DiskDuster never asks.
- **Always Ignore** — Right-click any item to skip it in future scans.
- **Preserve apps** — Keep everything an app owns, in every category, with one switch in the Apps view.
- **Apple Intelligence controls** — On Apple silicon Macs running macOS 27 or later, turn off the Apple Intelligence features you don't use and remove the models they downloaded (about 16 GB on a typical Mac). Fully reversible.

## Apple Intelligence

Starting with macOS 27, there is no single switch for Apple Intelligence, and its models stay on disk after features are turned off. (On macOS 26, use the Apple Intelligence switch in System Settings instead; DiskDuster hides this screen there.) DiskDuster can turn off the features you choose and remove their models, without touching `/System` directly:

1. DiskDuster creates a configuration profile that uses Apple's restriction keys and managed preferences to switch the chosen features off. It also stops macOS from downloading the removed models again.
2. You approve the profile in **System Settings → General → Device Management**. macOS requires this step and asks you to approve it with your password or biometrics.
3. Once the profile is installed, DiskDuster asks Apple's own asset service to remove the models that no remaining feature needs. If macOS reports a model differently than expected, DiskDuster leaves it alone.

To undo everything, choose **Turn Everything Back On** in DiskDuster, or remove the "DiskDuster: Apple Intelligence Off" profile in System Settings. macOS downloads models again when a feature needs them. Dictation and other speech features aren't affected.

## What DiskDuster Never Touches

- Anything outside the fixed list of locations in [`LocationCatalog.swift`](DiskDuster/Model/LocationCatalog.swift). Every item is re-checked against that list immediately before it is removed.
- Folders reached through a symbolic link.
- Localization files inside apps. Removing them breaks the app's code signature.
- `/System`, which is protected by System Integrity Protection.
- Your simulators (`~/Library/Developer/CoreSimulator/Devices`).
- iCloud sync caches and DiskDuster's own files.

## Full Disk Access

macOS hides app containers and the Trash from apps that don't have Full Disk Access. DiskDuster works without it, but finds less. To grant it, open **System Settings → Privacy & Security → Full Disk Access**, turn on DiskDuster (or click **+** to add it), then quit and reopen DiskDuster.

## Privacy

DiskDuster does not collect, send, or share your data. It contains no trackers or analytics and makes no network connections. Read more in our full [Privacy Policy](./PRIVACY.md).

## Requirements

### Running

- A Mac running macOS 26 or later

### Developer

- Xcode 26 or later, including Command Line Tools
- SwiftLint (`brew install swiftlint`)

## Building

```bash
make build
```

This lints, runs the unit tests, and builds `build/DiskDuster.app`. You can also open `DiskDuster.xcodeproj` in Xcode and run it (⌘R).

The project doesn't set a development team, so Xcode signs local builds with "Sign to Run Locally" and you don't need an Apple developer account to contribute. If you'd rather sign with your own team (for example, so macOS remembers DiskDuster's Full Disk Access between builds), create an untracked `Local.xcconfig` in the repository root:

```
DEVELOPMENT_TEAM = YOURTEAMID
```

With that file in place, `make build` signs with your team too (Xcode must be signed in to that team's account so it can create a development certificate).

Please don't set a team in Xcode's Signing & Capabilities tab, because that writes it into the project file.

Debug builds accept launch arguments that help with testing and screenshots:

```bash
open build/DiskDuster.app --args -DDAutoScan YES -DDSidebar developer
```

## Tech Stack

- SwiftUI
- Swift 6 concurrency
- AppKit (Finder, Trash and workspace integration)

## Contributor Disclosure

Humans write this software with AI Assistance. All contributions are well-tested and merged only after being reviewed and approved by humans who fully understand and take responsibility for the contribution.

While we welcome Pull Requests and other contributions from other humans (including AI-generated code), we do not accept contributions from AI bots. A human must review, understand, and sign off on all commits. Please file an issue to discuss any proposed feature before working on it.

## Trademark Notice

DiskDuster and its logo are trademarks of Centennial OSS Inc.
Use of the name and branding is not permitted for modified versions or forks without permission.
See TRADEMARKS.md for details.
