# Claude Usage Widget

A lightweight macOS desktop widget that displays your Claude Code usage metrics in real-time.

## Features

- **5-Hour Window** - Shows current usage within the rolling 5-hour limit
- **Weekly Usage** - Displays 7-day usage for all models, Sonnet, and Opus separately
- **Token Stats** - Today's and weekly token/message counts from local stats
- **Auto-refresh** - Updates automatically with configurable intervals
- **Always on Top** - Stays visible while you work (toggleable)
- **Draggable** - Position anywhere on screen
- **Launch at Login** - Starts automatically with macOS

## Requirements

- macOS 10.15+
- Claude Code installed and signed in (for OAuth credentials)

## Installation

### From Release

Download the latest `.dmg` from the releases page and drag to Applications.

### Build from Source

```bash
# Install dependencies
npm install

# Development mode
npm run tauri dev

# Build release
npm run tauri build
```

The built app will be at `src-tauri/target/release/bundle/macos/Claude Usage Widget.app`

## How It Works

The widget reads your Claude Code OAuth token from the macOS Keychain and fetches usage data from the Anthropic API. Local token statistics are read from `~/.claude/stats-cache.json`.

## Tech Stack

- **Frontend**: React + TypeScript + Vite
- **Backend**: Tauri 2 (Rust)
- **Styling**: Tailwind CSS with Anthropic brand colors

## License

MIT
