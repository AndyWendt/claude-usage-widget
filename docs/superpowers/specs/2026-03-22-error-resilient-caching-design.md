# Error-Resilient Caching for Claude Usage Widget

**Date:** 2026-03-22
**Status:** Approved

## Problem

When the API fetch fails (network error, auth expiry, server error), the widget and popover discard all usage data and show a full-screen error. Users lose visibility into their usage until the next successful fetch, even though the last-known data is still useful.

## Solution

Preserve the most recent successful API data on error. Display cached usage metrics alongside an error indicator and "last updated X ago" timestamp. Both the macOS widget and menu bar popover benefit.

## Model Changes

### `UsageSnapshot`

Add one optional field:

```swift
let lastSuccessfulUpdate: Date?
```

Semantics:
- `lastUpdated` — when this snapshot was written (always `Date()` on write)
- `lastSuccessfulUpdate` — when API data was last successfully fetched; carried forward on error, set to `Date()` on success
- `error` — existing field; `nil` on success, error message string on failure

A snapshot can now carry **both** valid usage data and an error simultaneously. This is the key behavioral change.

**Backwards compatibility note:** `UsageSnapshot` uses auto-synthesized `Codable` conformance. The new optional field decodes as `nil` from existing serialized data with no migration needed. If a custom `init(from:)` is ever added, it must use `decodeIfPresent` for `lastSuccessfulUpdate`.

Add a computed property to centralize the "has data" check:

```swift
var hasUsageData: Bool {
    fiveHour != nil || sevenDay != nil
}
```

### `UsageSnapshot` convenience

Add a helper to merge an error into an existing snapshot, accepting optional fresh `tokenStats`:

```swift
func withError(_ message: String, tokenStats: TokenStats? = nil) -> UsageSnapshot {
    UsageSnapshot(
        fiveHour: fiveHour,
        sevenDay: sevenDay,
        sevenDaySonnet: sevenDaySonnet,
        sevenDayOpus: sevenDayOpus,
        tokenStats: tokenStats ?? self.tokenStats,
        lastUpdated: Date(),
        lastSuccessfulUpdate: lastSuccessfulUpdate,
        error: message
    )
}
```

The `tokenStats` parameter allows callers to inject freshly-read local stats rather than using stale cached stats, keeping behavior consistent with the success path.

## UsageManager Changes

### `refresh()` — Error Paths

There are **two** error paths that both need the same caching treatment:

1. **Token error** (keychain failure) — lines 67-77 in current code
2. **API error** (network/server/auth failure) — lines 93-105 in current code

Both currently create a new snapshot with `nil` for all usage metrics, discarding cached data. Both will be updated to preserve cached data.

**New behavior for both error paths:**

```
1. Resolve existing data: use in-memory self.snapshot, or fall back to containerService.readSnapshot()
2. Read fresh stats from statsService (already done at top of refresh())
3. If existing data has usage metrics (existingSnapshot.hasUsageData):
     snapshot = existingSnapshot.withError(msg, tokenStats: stats)
     try containerService.writeSnapshot(snapshot)   // NEW: write on error
     widgetReloader()                                // NEW: reload on error
4. If no existing data (first launch, or container read also failed):
     snapshot = UsageSnapshot(fiveHour: nil, ..., error: msg)  // same as today
```

**Important:** `containerService.writeSnapshot()` and `widgetReloader()` are **new additions** to the error paths. Currently only the success path writes to the container and reloads the widget. The error path must now do both so the widget picks up the error indicator alongside cached data.

**Container read failure during error resolution:** If both the in-memory snapshot is `nil` (e.g., app just launched) and `containerService.readSnapshot()` returns `nil` (e.g., container file corrupted or missing), we fall through to case 4 — a data-less error snapshot, same as today. This is acceptable because the next successful API fetch will repopulate both the in-memory snapshot and the container.

### `refresh()` — Success Path

```
snapshot = response.toSnapshot(tokenStats: stats)
// lastSuccessfulUpdate = Date(), error = nil
```

`APIResponse.toSnapshot()` updated to set `lastSuccessfulUpdate: Date()` and `error: nil`.

### Token Cache Clearing

Unchanged — 401/403 still clears `cachedToken` to force re-auth on next attempt.

## Popover UI Changes

### `PopoverView.contentView`

The error banner already renders at the bottom of the content view when `snapshot.error != nil`. With caching, usage bars will now render from cached data even during errors.

Add a "last updated" line below the error banner. Use `.offset` style (produces "2 minutes") rather than `.relative` (produces "2 min. ago") to avoid "ago ago":

```swift
if let error = snapshot.error {
    errorBanner(error)
    if let lastSuccess = snapshot.lastSuccessfulUpdate {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 9))
            Text("Last updated ")
                .font(.system(size: 9))
            + Text(lastSuccess, style: .relative)
                .font(.system(size: 9))
        }
        .foregroundStyle(AnthropicColors.creamMuted)
    }
}
```

No other popover changes needed — the usage bars, token stats, and divider render identically whether the data is fresh or cached.

## Widget UI Changes

### Decision Logic

All widget views need to distinguish three states:

1. **No data at all** (`!snapshot.hasUsageData && error != nil`) — render `WidgetErrorView` as today
2. **Data + error** (`snapshot.hasUsageData && error != nil`) — render normal widget view with error indicator
3. **Data, no error** — render normal widget view as today

### Error Indicator (all sizes)

When state is "data + error", add a small indicator:

```swift
private var errorIndicator: some View {
    HStack(spacing: 2) {
        Image(systemName: "exclamationmark.circle.fill")
            .font(.system(size: 8))
            .foregroundStyle(AnthropicColors.coral)
        if let lastSuccess = snapshot.lastSuccessfulUpdate {
            Text(lastSuccess, style: .relative)
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
    }
}
```

### SmallWidgetView

Replace the existing `staleIndicator` area: show `errorIndicator` if `snapshot.error != nil`, otherwise show `staleIndicator` if `snapshot.isStale`. They occupy the same space — bottom of the widget.

### MediumWidgetView

Same replacement in the bottom-right area where the stale indicator currently lives.

### LargeWidgetView

Same replacement in the bottom area.

### WidgetErrorView

Unchanged — continues to handle the truly-no-data case.

### Widget Entry Point

Update the condition that decides between `WidgetErrorView` and the normal view. Currently checks `snapshot.fiveHour == nil`. Update to use `!snapshot.hasUsageData` so that any cached usage data (five-hour or seven-day) triggers the normal view with error indicator rather than the full error screen:

```swift
// Before:
if entry.snapshot.error != nil && entry.snapshot.fiveHour == nil { ... }

// After:
if entry.snapshot.error != nil && !entry.snapshot.hasUsageData { ... }
```

## Timeline Provider

No changes needed. `UsageTimelineEntry.buildTimeline(from:)` already handles `nil` snapshot for the no-data case. Now that errors preserve the snapshot data, the provider will build normal timeline entries with the cached data included.

**Reload policy note:** When a snapshot has cached data + error, `snapshot != nil` so the timeline uses the normal `.atEnd` reload policy (not the aggressive 5-min retry). Retry logic remains the app's responsibility via its refresh timer. This is intentional — the widget has displayable data so aggressive retries are unnecessary.

## Shared Container

No changes to `SharedContainerService`. The only difference is that `UsageManager` now writes snapshots with both data and error on failure (previously it only wrote on success).

## Test Changes

### Existing Tests to Update

- **UsageManagerTests**: Snapshot construction calls need `lastSuccessfulUpdate` parameter
- **TimelineProviderTests**: Snapshot construction calls need `lastSuccessfulUpdate` parameter
- **SharedContainerServiceTests**: Snapshot construction calls need `lastSuccessfulUpdate` parameter

### New Tests

1. **Error preserves cached data**: After a successful fetch followed by an API error, verify the snapshot retains usage metrics from the successful fetch
2. **Error indicator with no prior data**: First-ever fetch fails — verify snapshot has nil usage metrics and error (same as today)
3. **lastSuccessfulUpdate carries forward**: After success then error, verify `lastSuccessfulUpdate` matches the success time, not the error time
4. **Success clears error**: After error then success, verify `error` is nil and `lastSuccessfulUpdate` is updated
5. **Container written on error with cached data**: Verify the merged snapshot is written to the shared container on error
6. **Widget reload on error**: Verify `widgetReloader()` is called even on error (so widget picks up error indicator)
7. **App restart with container data and API failure**: In-memory snapshot is nil, container has valid cached data, API fails — verify container data is read and merged with error into the new snapshot
8. **Token error preserves cached data**: After a successful fetch, keychain read fails — verify snapshot retains usage metrics (covers the token error path, not just the API error path)
9. **Fresh tokenStats used on error**: After error with cached data, verify `tokenStats` in the snapshot reflects the freshly-read stats, not the stale cached stats

## Migration / Backwards Compatibility

`lastSuccessfulUpdate` is optional (`Date?`), so existing serialized snapshots decode with `nil` for this field. No migration needed. The widget and popover treat `nil` as "unknown" and skip the "last updated" display.

This relies on auto-synthesized `Codable` conformance. If a custom `init(from:)` is ever added to `UsageSnapshot`, it must use `decodeIfPresent` for `lastSuccessfulUpdate`.

## Files Modified

| File | Change |
|------|--------|
| `Shared/Models/UsageSnapshot.swift` | Add `lastSuccessfulUpdate`, `hasUsageData`, `withError()` helper |
| `Shared/Models/APIModels.swift` | Update `toSnapshot()` to set `lastSuccessfulUpdate` |
| `App/UsageManager.swift` | Preserve cached data on both error paths, write to container + reload widget on error |
| `App/Views/PopoverView.swift` | Add "last updated" line below error banner |
| `Widget/Views/SmallWidgetView.swift` | Add error indicator, conditional with stale indicator |
| `Widget/Views/MediumWidgetView.swift` | Add error indicator, conditional with stale indicator |
| `Widget/Views/LargeWidgetView.swift` | Add error indicator, conditional with stale indicator |
| `Widget/ClaudeUsageWidgetBundle.swift` | Update error-vs-data condition to use `hasUsageData` |
| `Tests/UsageManagerTests.swift` | Update snapshots, add 5 new error-caching tests |
| `Tests/TimelineProviderTests.swift` | Update snapshots |
| `Tests/SharedContainerServiceTests.swift` | Update snapshots |
