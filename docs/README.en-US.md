<p align="center">
  <img src="../Assets/Brand/READMEHeader.svg" alt="SeguraMinhasNotas — macOS, Swift, and the MIT License" width="100%">
</p>

<p align="center">
  <a href="../README.md">Português do Brasil</a> ·
  <strong>English (United States)</strong> ·
  <a href="README.es-CO.md">Español (Colombia)</a>
</p>

<p align="center">
  A deck of quick notes at the edge of your Mac: native, local-first, account-free, and telemetry-free.
</p>

## Overview

**SeguraMinhasNotas** is an open-source macOS app. It keeps a small colorful stack at the side of the screen, taking up almost no space while at rest. Move the pointer to the edge and the deck fans out; click a card and it becomes a floating editor.

The app is built with Swift, SwiftUI, and AppKit, requires macOS 13 or later, and does not need a server to create, edit, or organize notes. Primary content stays on the Mac and can optionally be synced through a folder selected by the user.

## Visual tour

### First launch

<p align="center">
  <img src="images/01-onboarding.png" alt="Welcome screen explaining how to find notes at the edge" width="620">
</p>

The onboarding flow introduces the edge gesture, the fanning deck, autosave, and global keyboard shortcuts.

### Side deck: resting and open

| At rest | Fanned open |
|---|---|
| <img src="images/02-deck-resting.png" alt="Collapsed deck shown as small colored marks" width="340"> | <img src="images/03-deck-open.png" alt="Note deck fanned open at the edge" width="340"> |

- At rest, each note occupies only a small colored mark at the edge.
- The deck can open on hover or click.
- Up to eight cards are shown directly; additional notes remain available in the library.
- You can keep the deck open, switch screen sides, and drag cards to reorder them.
- Each display gets its own panel, and the app can follow every Space and full-screen app.

### Floating editor and checklists

<p align="center">
  <img src="images/04-editor-checklists.png" alt="Floating editor with a title, checklist, tags, and colors" width="520">
</p>

The editor is movable and resizable. It supports a title, body, tags, clickable checklists, five colors, four system font styles, and adjustable sizing. Changes are saved 250 ms after typing stops. A pinned note returns to the desktop the next time the app opens.

### Library, search, archive, and export

<p align="center">
  <img src="images/05-all-notes.png" alt="Library with search, filters, multi-selection, preview, and export" width="100%">
</p>

The **All Notes** window provides title/body/tag search, active and archived filters, preview, restore, a 10-second delete undo, import, and batch export.

### General and appearance settings

| General | Appearance |
|---|---|
| <img src="images/06-settings-general.png" alt="General deck and automatic launch settings" width="520"> | <img src="images/07-settings-appearance.png" alt="Font, size, and live preview settings" width="520"> |

**General** controls automatic launch, full-screen behavior, screen side, opening gesture, and animation speed. **Appearance** controls the font and size with an immediate preview.

### Sync and privacy

| Sync | Privacy |
|---|---|
| <img src="images/08-settings-sync.png" alt="Optional sync through a user-selected folder" width="520"> | <img src="images/09-settings-privacy.png" alt="Encryption, authentication, and permissions settings" width="520"> |

Sync is optional and works with a folder in iCloud Drive, Dropbox, or another provider. The privacy page explains what is encrypted, where the local file lives, when networking is used, and which permissions the app does not request.

### Updates and protected content

| About and updates | Locked notes |
|---|---|
| <img src="images/10-settings-about.png" alt="Version, license, and update options" width="520"> | <img src="images/11-protected-notes.png" alt="Locked library waiting for local authentication" width="520"> |

Optional locking uses `LocalAuthentication`: Touch ID, Apple Watch, or the Mac password. The app only receives the result of the system authentication request.

## Feature set

| Area | Capabilities |
|---|---|
| Edge | Left or right panel, one panel per display, compact rest state, animated fan, and always-open mode. |
| Notes | Floating editor, resize, pin, 250 ms autosave, title, body, tags, and five colors. |
| Checklists | Clickable boxes, automatic continuation on Return, and correct Markdown conversion. |
| Organization | Diacritic-insensitive search, active/archive states, restore, reorder, and delete undo. |
| Appearance | Rounded, system, serif, and monospaced fonts, with sizes from 13 to 28 points. |
| Languages | Brazilian Portuguese, U.S. English, and Colombian Spanish; follows macOS and supports a per-app language choice. |
| Portability | Import, batch export, and a complete backup archive. |
| Sync | One readable file per note in any user-selected synced folder. |
| Privacy | Local AES-GCM body encryption, Keychain storage, optional authentication, and no telemetry. |
| macOS | Global shortcuts, multiple displays, Spaces, full screen, automatic launch, and Sparkle updates. |

## How to use it

1. Open SeguraMinhasNotas. It runs as a utility app and does not occupy permanent Dock space.
2. Move the pointer to the colored marks at the side of the screen.
3. Click a card to open its editor, or use `+` to create a note.
4. Right-click the deck to open All Notes, the archive, or Settings.
5. Enable **Open automatically when the Mac starts** if you want the deck available with every macOS session.

macOS may require confirmation under **System Settings › General › Login Items**.

The interface follows your macOS language preference. To choose a language only for SeguraMinhasNotas, open **System Settings › General › Language & Region › Applications**, add the app, and select **Portuguese (Brazil)**, **English (US)**, or **Spanish (Colombia)**. Quit and reopen SeguraMinhasNotas to apply the change.

## Keyboard shortcuts

| Action | Shortcut |
|---|---|
| New note | `⌥⌘N` |
| All Notes | `⌥⌘A` |
| Archive | `⌥⌘L` |
| Close the current editor | `⌘W` |

Shortcuts are registered through native macOS APIs and do not require Accessibility or Input Monitoring permission.

## Import and export

### Export

- **Markdown:** one `.md` file per note, preserving checklists.
- **Plain text:** one `.txt` file per note.
- **Single document:** every selected note in one Markdown file.
- **SeguraMinhasNotas archive:** a `.seguranotas` package for backup and restore.
- **Portable archive:** the project's structured `.stickies` package.

### Import

- `.seguranotas` and `.stickies` files;
- Markdown and plain text;
- RTF files and RTFD packages exported by Stickies;
- folders containing multiple supported files.

## Data, sync, and privacy

Primary storage is located at:

```text
~/Library/Application Support/SeguraMinhasNotas/notes.json
```

- Each note's **body** is encrypted with AES-GCM.
- A random 256-bit key is stored in Keychain and is not marked as synchronizable.
- Titles, tags, colors, and lifecycle metadata remain readable in the local envelope for indexing and recovery.
- There is no built-in analytics, telemetry, or crash reporting.
- Sparkle uses the network to check the update feed. Note sync happens through the folder you selected, not through a project server.
- Folder-sync `.seguranota` files are intentionally readable for portability. Use a folder with a privacy policy you trust.
- Locking can hide all content while the Mac screen is locked and require local authentication after returning.

See [SECURITY.md](../SECURITY.md) for the security model and vulnerability reporting instructions.

## Requirements and installation

### Requirements

- macOS 13 Ventura or later;
- an Apple Silicon or Intel Mac supported by the toolchain used for the build;
- Swift 6 and Xcode Command Line Tools to build from source.

### Build from source

```bash
git clone https://github.com/lrqnet/SeguraMinhasNotas.git
cd seguraminhasnotas
./scripts/check.sh
./scripts/build-app.sh
open .build/SeguraMinhasNotas.app
```

The first build downloads Sparkle through Swift Package Manager. Local bundles receive an ad hoc signature suitable for local development.

## Architecture

| Component | Implementation |
|---|---|
| Interface | SwiftUI for views and AppKit for panels, floating windows, and macOS integration. |
| State | Observable `NoteStore`, `MainActor` operations, and persistence serialized away from UI work. |
| Persistence | JSON envelope with AES-GCM note bodies and a Keychain-stored key. |
| Authentication | `LocalAuthentication` using the device-owner policy. |
| Automatic launch | `SMAppService.mainApp`; macOS owns approval and status. |
| Updates | Sparkle 2.9.6; public releases must be signed. |
| Distribution | Swift Package Manager, an `.app` bundle, Apple signing, and a ZIP archive. |

The app uses `LSUIElement`, so it behaves like a background utility without a permanent Dock icon. Source code lives in [`Sources/SeguraMinhasNotas`](../Sources/SeguraMinhasNotas).

## Development and validation

Run the local checks:

```bash
./scripts/check.sh
./scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 .build/SeguraMinhasNotas.app
```

Read [CONTRIBUTING.md](../CONTRIBUTING.md) before submitting a change.

## Authorship

Created and maintained by [Lucas Quaresma](https://github.com/lrqnet).

## MIT License

This project is free and open-source software under the [MIT License](../LICENSE). In practical terms, anyone may:

- use the code for personal or commercial purposes;
- copy, modify, and merge it into other projects;
- publish and distribute original or modified versions;
- sublicense or sell copies of the software.

The main condition is that the copyright notice and license text remain in copies or substantial portions. The software is provided **without warranty**. In other words: yes, you may copy it, adapt it, and build whatever you want on top of it, including commercial products, while preserving that notice.
