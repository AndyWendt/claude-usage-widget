# Claude Usage Widget — Native Swift macOS App Design

## Overview

Convert the existing Tauri-based Claude Usage Widget into a native Swift/SwiftUI macOS app with WidgetKit desktop widgets and a menu bar popover. The app provides glanceable Claude Code usage monitoring.

## Deliberate Changes from Existing Tauri App

The following features from the existing Tauri app are intentionally dropped or changed:

- **Always-on-top / floating panel** — Dropped. The new app uses a menu bar popover (anchored to the menu bar, dismisses on click-away) and WidgetKit desktop widgets instead of a persistent floating window. No `always_on_top` setting needed.
- **Window dragging** — Dropped. The popover is anchored to the menu bar icon; desktop widgets are repositioned via macOS's native widget editing mode. No custom drag logic needed.
- **Window position persistence** — Dropped. The popover position is determined by the menu bar icon location. Widget positions are managed by macOS.
- **First-launch autostart consent dialog** — Changed. The existing app shows a dialog on first launch asking about launch-at-login. The new app does not prompt — the user enables it explicitly from the settings panel. Simpler and less intrusive.
- **Default refresh interval** — Changed from 60 seconds to 5 minutes (300 seconds). The existing 60-second default was designed for active monitoring. Since this app targets glanceable use, 5 minutes reduces API load while keeping data reasonably fresh. Users can configure down to 1 minute if they prefer the old behavior.
- **Settings file location** — Changed from `~/.claude-widget/settings.json` to `UserDefaults` (macOS-native approach). No migration from the old settings file is provided — settings will reset to defaults on first launch of the Swift app.
- **`sessionCount` and `toolCallCount` from stats-cache.json** — These fields exist in the local stats file but were never surfaced in the UI. They are not included in the new data model.

## Architecture

### Two Targets

1. **ClaudeUsageWidget (main app)** — Menu bar-only app (no Dock icon). Runs in background, manages data fetching, Keychain access, and writes usage snapshots to a shared App Group container. Provides a rich popover via `MenuBarExtra` with `.menuBarExtraStyle(.window)`.

2. **ClaudeUsageWidgetExtension (WidgetKit extension)** — Desktop widgets in three sizes (small, medium, large). Reads usage data from the shared App Group container. Never touches the network or Keychain.

### Data Flow

```
Keychain ──> Main App ──> API call ──────> UsageSnapshot ──> Shared Container ──> WidgetKit Extension
                      └── stats-cache.json ──┘                    │
                                                                  └── reloadTimelines()
```

### Key Decisions

- **Approach A (pure SwiftUI)** — `MenuBarExtra` with `.menuBarExtraStyle(.window)` modifier for the popover, SwiftUI views throughout, AppKit only where required (Keychain access)
- **Non-sandboxed main app** — Required for reading Claude Code's Keychain entry
- **Sandboxed widget extension** — Reads only from shared container
- **Minimum deployment target:** macOS 14 (Sonoma) — required for desktop widgets
- **Ad-hoc signing for main app initially** — WidgetKit extension requires at minimum a free Apple Developer account for a valid team ID (see Code Signing section)

## Menu Bar Popover (Rich Detail View)

### Trigger

Click the menu bar icon (SF Symbol `gauge.medium`).

### Layout

- **Header:** "Claude Code Usage" title + manual refresh button (spinner while loading)
- **Usage bars:**
  - 5-Hour Window — progress bar + "Resets in Xh Xm"
  - Weekly (All Models) — progress bar + reset timer
  - Weekly (Sonnet) — progress bar + reset timer
  - Weekly (Opus) — progress bar + reset timer
- **Divider**
- **Token stats:** Today tokens / This week tokens (formatted with K/M abbreviations). Message counts are carried in the data model but not displayed in the UI.
- **Footer:** Settings gear icon — toggles for launch-at-login, refresh interval picker

### Progress Bar Styling (Hybrid)

Native widget materials/chrome for the popover background. Anthropic accent colors for progress bars:

- **0-69% (normal):** Tan gradient (`#B8956A` to `#D4A574`). Opus variant uses brown-tan (`#8B7355` to `#E8D4BC`) at this level only.
- **70-89% (warning):** Coral/warning gradient (coral-dark to `#E07A5F`). Overrides Opus-specific colors.
- **90-100% (danger):** Red/danger gradient (`#A85040` to coral) with pulse animation. Overrides Opus-specific colors.

### Popover Size

~260x400 points.

## WidgetKit Desktop Widgets

### Small (`.systemSmall`)

- 5-hour window progress bar with percentage
- Reset timer below
- Single-metric glance

### Medium (`.systemMedium`)

- 5-hour window + Weekly (All Models) side by side
- Each with progress bar, percentage, reset timer

### Large (`.systemLarge`)

- All four usage bars (5-hour, weekly all, weekly Sonnet, weekly Opus)
- Token stats section (today + this week)
- Full dashboard

### Styling

- Native widget background material (adapts to light/dark mode, wallpaper tinting)
- Anthropic accent colors for progress bar fills (same scheme as popover, including Opus override behavior)
- SF Symbols for icons
- System fonts with monospaced digits for numbers/timers

### Stale Data Indicator

If data is older than 30 minutes, show a small clock icon with muted text "Updated Xm ago" at the bottom of each widget size. Uses `Text(date, style: .relative)` for automatic updating.

### Error & Empty States

- **Placeholder view (shown while loading):** Redacted progress bars with placeholder percentages, standard WidgetKit redaction style.
- **Snapshot (for widget gallery preview):** Static mock data showing ~45% on 5-hour, ~30% on weekly.
- **No data state (shared container missing or empty):** Show "Open Claude Usage Widget to get started" text with the app icon.
- **Error state (error field set in snapshot):** Show warning icon with "Unable to fetch usage" text and last-known data if available.

### Timeline Strategy

- `.atEnd` reload policy
- Timeline entries spaced 15 minutes apart with same data (reset timers count down naturally using `Text(date, style: .timer)`)
- Main app calls `reloadTimelines` after each successful API fetch

### Interactivity

- Tap anywhere on widget opens the main app via URL scheme `claudeusage://open`
- URL scheme registered in main app's Info.plist under `CFBundleURLSchemes`
- Main app handles incoming URL via `.onOpenURL { url in }` modifier — currently just activates the app (popover appears via menu bar click)
- No interactive buttons on widgets

## Data Layer

### Keychain Access (main app only)

- `Security` framework, `SecItemCopyMatching` with `kSecClassGenericPassword`
- Service: `"Claude Code-credentials"`, Account: `NSUserName()`
- Parses JSON, extracts `claudeAiOauth.accessToken`
- Token cached in memory, cleared on 401/403 errors
- First launch triggers a one-time macOS Keychain authorization prompt

### API Call

- `GET https://api.anthropic.com/api/oauth/usage`
- Headers: `Authorization: Bearer {token}`, `anthropic-beta: oauth-2025-04-20`
- Response decoded with `JSONDecoder` into `UsageApiResponse` model
- The `utilization` field from the API is a value in the range 0.0–100.0 (percentage). No conversion needed — pass directly to progress bar views.

### Local Stats

- Reads `~/.claude/stats-cache.json` via `FileManager`
- Calculates today's and last 7 days' token counts and message counts

### Shared Container (App Group)

- App Group: `group.com.andywendt.claude-usage-widget`
- Single JSON file: `usage-snapshot.json`
- Written by main app after every successful fetch
- Read by WidgetKit extension's `TimelineProvider`

**macOS caveat for non-sandboxed apps:** `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)` returns `nil` for non-sandboxed apps. The main app must construct the shared container path manually:
```
~/Library/Group Containers/group.com.andywendt.claude-usage-widget/usage-snapshot.json
```
The sandboxed WidgetKit extension can use `containerURL(forSecurityApplicationGroupIdentifier:)` normally.

### Data Model (shared between both targets)

```
UsageSnapshot: Codable
  fiveHour: UsageMetric?        (percent: Double, resetsAt: Date)
  sevenDay: UsageMetric?
  sevenDaySonnet: UsageMetric?
  sevenDayOpus: UsageMetric?
  tokenStats: TokenStats         (todayTokens: Int, weekTokens: Int, todayMessages: Int, weekMessages: Int)
  lastUpdated: Date
  error: String?
```

Note: `todayMessages` and `weekMessages` are included in the model for completeness but are not displayed in the current UI design. They may be surfaced in a future version.

### Refresh Lifecycle

1. Timer fires (default every 5 minutes, configurable) or manual refresh triggered
2. Read token from cache (or Keychain if cache empty)
3. Fetch API + read stats-cache.json in parallel (using Swift concurrency `async let`)
4. Combine into `UsageSnapshot`
5. Update popover UI via `@Published` property
6. Write snapshot to shared container
7. Call `WidgetCenter.shared.reloadTimelines(ofKind:)`

### Refresh Interval

- Default: 5 minutes (300 seconds) — deliberately slower than the existing Tauri app's 60-second default (see Deliberate Changes section)
- Configurable: 1 min, 2 min, 5 min, 10 min, 15 min
- Manual refresh always available
- Persisted in UserDefaults

## Settings & Persistence

### UserDefaults

- `refreshInterval`: Int (seconds, default 300)
- `launchAtLogin`: Bool (default false)

### Launch at Login

- `SMAppService.mainApp.register()` / `.unregister()`
- Status always read from `SMAppService.mainApp.status` (users can toggle in System Settings)
- Toggle exposed in popover settings

### App Behavior

- No Dock icon: `LSUIElement = true` in Info.plist
- No first-launch autostart dialog (see Deliberate Changes section)

## Project Structure

```
ClaudeUsageWidget/
  ClaudeUsageWidget.xcodeproj
  Shared/                              # Code shared between both targets
    Models/
      UsageSnapshot.swift              # UsageMetric, TokenStats, UsageSnapshot
    Services/
      KeychainService.swift            # SecItemCopyMatching wrapper
      APIService.swift                 # URLSession fetch from Anthropic
      StatsService.swift               # Read ~/.claude/stats-cache.json
    Theme/
      AnthropicColors.swift            # Tan, coral, charcoal color definitions
  App/                                 # Main menu bar app target
    ClaudeUsageWidgetApp.swift         # @main, MenuBarExtra scene, onOpenURL handler
    UsageManager.swift                 # Timer, data fetching, shared container writes
    Views/
      PopoverView.swift                # Full detail view (header, bars, stats)
      UsageBarView.swift               # Progress bar with gradient fills
      TokenStatsView.swift             # Today/week token display
      ResetTimerView.swift             # Countdown text
      SettingsView.swift               # Refresh interval, launch at login
    Info.plist                         # LSUIElement = true, CFBundleURLSchemes
  Widget/                              # WidgetKit extension target
    ClaudeUsageWidgetBundle.swift
    UsageTimelineProvider.swift        # Reads shared container, builds timeline
    Views/
      SmallWidgetView.swift            # 5-hour only
      MediumWidgetView.swift           # 5-hour + weekly
      LargeWidgetView.swift            # Full dashboard
      PlaceholderView.swift            # Redacted loading state
      ErrorView.swift                  # No data / error states
    Info.plist
  Assets.xcassets                      # App icon, widget preview images
```

~18-20 Swift files total.

## Code Signing & Distribution

### Signing

- **Main app:** Ad-hoc signing initially ("Sign to Run Locally"). Works for personal use.
- **WidgetKit extension:** Requires at minimum a free Apple Developer account to get a valid Team ID. Ad-hoc signed widget extensions will not load on macOS. A free account provides a development signing certificate sufficient for running on your own machine — no paid Developer Program membership needed for this.
- Developer ID Application certificate (paid program) can be added later for distribution to others.

### Entitlements

- Main app: `com.apple.security.application-groups` (shared container)
- Widget extension: `com.apple.security.application-groups` + `com.apple.security.app-sandbox = true`
- No Keychain entitlement needed — non-sandboxed apps access login keychain without one

### URL Scheme

Register in main app's Info.plist:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>claudeusage</string>
    </array>
  </dict>
</array>
```

### Future Distribution

- Requires Apple Developer Program membership ($99/yr)
- Developer ID Application certificate for signing
- Notarization via `xcrun notarytool` for Gatekeeper approval
- Not needed for personal use on your own machine
