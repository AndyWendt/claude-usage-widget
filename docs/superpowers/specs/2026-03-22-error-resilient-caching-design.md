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

### `UsageSnapshot` convenience

Add a helper to merge an error into an existing snapshot:

```swift
func withError(_ message: String) -> UsageSnapshot {
    UsageSnapshot(
        fiveHour: fiveHour,
        sevenDay: sevenDay,
        sevenDaySonnet: sevenDaySonnet,
        sevenDayOpus: sevenDayOpus,
        tokenStats: tokenStats,
        lastUpdated: Date(),
        lastSuccessfulUpdate: lastSuccessfulUpdate,
        error: message
    )
}
```

## UsageManager Changes

### `refresh()` — Error Path

Current behavior on error:
```
snapshot = UsageSnapshot(fiveHour: nil, sevenDay: nil, ..., error: msg)
```

New behavior on error:
```
1. Resolve existing data: use in-memory snapshot, or read from shared container
2. If existing data has usage metrics:
     snapshot = existingSnapshot.withError(msg)
     Write to container, reload widget
3. If no existing data (first launch):
     snapshot = UsageSnapshot(fiveHour: nil, ..., error: msg)  // same as today
```

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

Add a "last updated" line below the error banner:

```swift
if let error = snapshot.error {
    errorBanner(error)
    if let lastSuccess = snapshot.lastSuccessfulUpdate {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 9))
            Text("Data from ")
                .font(.system(size: 9))
            + Text(lastSuccess, style: .relative)
                .font(.system(size: 9))
            + Text(" ago")
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

1. **No data at all** (`fiveHour == nil && sevenDay == nil && error != nil`) — render `WidgetErrorView` as today
2. **Data + error** (usage fields populated, `error != nil`) — render normal widget view with error indicator
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

The existing widget entry views (in `ClaudeUsageWidgetBundle`) check `snapshot.error != nil && snapshot.fiveHour == nil` to decide whether to show `WidgetErrorView` vs the normal view. This check needs to be: show `WidgetErrorView` only when there's an error AND no cached usage data.

## Timeline Provider

No changes needed. `UsageTimelineEntry.buildTimeline(from:)` already handles `nil` snapshot for the no-data case. Now that errors preserve the snapshot data, the provider will build normal timeline entries with the cached data included.

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

## Migration / Backwards Compatibility

`lastSuccessfulUpdate` is optional (`Date?`), so existing serialized snapshots decode with `nil` for this field. No migration needed. The widget and popover treat `nil` as "unknown" and skip the "last updated" display.

## Files Modified

| File | Change |
|------|--------|
| `Shared/Models/UsageSnapshot.swift` | Add `lastSuccessfulUpdate`, add `withError()` helper |
| `Shared/Models/APIModels.swift` | Update `toSnapshot()` to set `lastSuccessfulUpdate` |
| `App/UsageManager.swift` | Preserve cached data on error, write to container on error |
| `App/Views/PopoverView.swift` | Add "last updated" line below error banner |
| `Widget/Views/SmallWidgetView.swift` | Add error indicator, conditional with stale indicator |
| `Widget/Views/MediumWidgetView.swift` | Add error indicator, conditional with stale indicator |
| `Widget/Views/LargeWidgetView.swift` | Add error indicator, conditional with stale indicator |
| `Tests/UsageManagerTests.swift` | Update snapshots, add new error-caching tests |
| `Tests/TimelineProviderTests.swift` | Update snapshots |
| `Tests/SharedContainerServiceTests.swift` | Update snapshots |
