# 🌳 GitGrove

See all your git worktrees in one place.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Screenshots

![Main View](screenshots/main.jpg?v=2)

![Worktree Details](screenshots/worktrees.jpg?v=2)

![Quick Switcher (⌘K)](screenshots/quick-switcher.jpg?v=2)

## Features

- **Scan & discover** — automatically finds all git repositories and worktrees across your folders
- **Instant startup** — caches scan results, loads instantly on reopen
- **Streaming scan** — repos appear in UI as they're found, no waiting
- **Quick Switcher (⌘K)** — spotlight-style search across all worktrees
- **One-click open** — Terminal, Finder, Cursor, Claude Code
- **Git status** — dirty indicators, last commit info, branch names
- **Disk usage** — computed in background, never blocks UI
- **Create & remove** worktrees from the app
- **Security-scoped bookmarks** — no Full Disk Access needed

## Install

```bash
git clone https://github.com/nicenemo/GitGrove.git
cd GitGrove
./build.sh
open build/GitGrove.app
```

## Requirements

- macOS 14+
- Git

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘K | Quick Switcher |
| ⌘R | Refresh |
| ↩ | Open in Terminal (Quick Switcher) |
| ⌘↩ | Open in Finder (Quick Switcher) |
| ⌥↩ | Open in Cursor (Quick Switcher) |

## Built With

- SwiftUI
- Swift Package Manager (no Xcode project needed)

## Support

If you find GitGrove useful:

☕ [Buy me a coffee](https://buymeacoffee.com/osa911)

## License

MIT
