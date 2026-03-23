# Claude Usage Widget

A native macOS menu bar app and desktop widget that displays your Claude Code usage metrics in real-time.

## Features

- **Menu Bar Icon** - Dynamic gauge icon changes color based on usage level (green/amber/coral/red)
- **5-Hour Window** - Shows current usage within the rolling 5-hour limit
- **Weekly Usage** - Displays 7-day usage for all models, Sonnet, and Opus separately
- **Pace Indicator** - Projected usage tracking showing if you're on pace to hit limits
- **Token Stats** - Today's and weekly token/message counts from local stats
- **Desktop Widgets** - WidgetKit widgets in small, medium, and large sizes
- **Auto-refresh** - Configurable refresh interval (1–15 min)
- **Launch at Login** - Starts automatically with macOS
- **Debug Logs** - Built-in log viewer for troubleshooting

## Requirements

- macOS 14.0+
- Claude Code installed and signed in (for OAuth credentials)

## Installation

### Build from Source

```bash
cd ClaudeUsageWidget
xcodebuild -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageWidget -configuration Release build
```

Or open `ClaudeUsageWidget/ClaudeUsageWidget.xcodeproj` in Xcode and build from there.

## How It Works

The menu bar app reads your Claude Code OAuth token from the macOS Keychain and fetches usage data from the Anthropic API. Local token statistics are read from `~/.claude/stats-cache.json`. Usage data is shared with the WidgetKit extension via an App Group container so desktop widgets stay in sync.

## Project Structure

```
ClaudeUsageWidget/
├── App/            # Menu bar app (SwiftUI MenuBarExtra)
│   ├── Views/      # PopoverView, SettingsView, UsageBarView, etc.
│   └── UsageManager.swift
├── Widget/         # WidgetKit extension (small/medium/large)
│   ├── Views/      # SmallWidgetView, MediumWidgetView, LargeWidgetView
│   └── UsageTimelineProvider.swift
├── Shared/         # Code shared between both targets
│   ├── Models/     # APIModels, UsageSnapshot, UsageTimelineEntry
│   ├── Services/   # APIService, KeychainService, StatsService, SharedContainerService
│   └── Theme/      # AnthropicColors, MenuBarIconTier
└── Tests/          # Unit tests
```

## Tech Stack

- **Swift** + **SwiftUI**
- **WidgetKit** for desktop widgets
- **XcodeGen** (`project.yml`) for project generation

## License

MIT
