import { UsageBar } from "./UsageBar";
import { ResetTimer } from "./ResetTimer";
import { TokenStats } from "./TokenStats";
import type { WidgetData } from "../hooks/useUsageData";

interface UsageWidgetProps {
  data: WidgetData | null;
  loading: boolean;
  error: string | null;
  onRefresh: () => void;
  isDragging: boolean;
}

export function UsageWidget({
  data,
  loading,
  error,
  onRefresh,
  isDragging,
}: UsageWidgetProps) {
  return (
    <div className={`widget ${isDragging ? "dragging" : ""}`}>
      {/* Header - draggable region */}
      <div className="widget-header" data-tauri-drag-region>
        <span className="widget-title" data-tauri-drag-region>
          Claude Code Usage
        </span>
        <button
          className="refresh-button"
          onClick={(e) => {
            e.stopPropagation();
            onRefresh();
          }}
          title="Refresh"
          disabled={loading}
        >
          <RefreshIcon spinning={loading} />
        </button>
      </div>

      {/* Error state */}
      {error && !data && (
        <div className="widget-error">
          <span className="error-icon">!</span>
          <span className="error-text">{error}</span>
        </div>
      )}

      {/* Loading state (only on initial load) */}
      {loading && !data && (
        <div className="widget-loading">
          <span className="loading-text">Loading...</span>
        </div>
      )}

      {/* Usage data */}
      {data && (
        <div className="widget-content">
          {/* 5-Hour Window */}
          {data.fiveHour && (
            <div className="usage-section">
              <div className="usage-label">5-Hour Window</div>
              <UsageBar percent={data.fiveHour.percent} />
              <ResetTimer resetsAt={data.fiveHour.resetsAt} />
            </div>
          )}

          {/* Weekly (All Models) */}
          {data.sevenDay && (
            <div className="usage-section">
              <div className="usage-label">Weekly (All Models)</div>
              <UsageBar percent={data.sevenDay.percent} />
              <ResetTimer resetsAt={data.sevenDay.resetsAt} />
            </div>
          )}

          {/* Weekly Sonnet */}
          {data.sevenDaySonnet && (
            <div className="usage-section">
              <div className="usage-label">Weekly (Sonnet)</div>
              <UsageBar percent={data.sevenDaySonnet.percent} />
              <ResetTimer resetsAt={data.sevenDaySonnet.resetsAt} />
            </div>
          )}

          {/* Weekly Opus */}
          {data.sevenDayOpus && (
            <div className="usage-section">
              <div className="usage-label">Weekly (Opus)</div>
              <UsageBar percent={data.sevenDayOpus.percent} variant="opus" />
              <ResetTimer resetsAt={data.sevenDayOpus.resetsAt} />
            </div>
          )}

          {/* Divider */}
          <div className="widget-divider" />

          {/* Token Stats */}
          <TokenStats stats={data.tokenStats} />

          {/* API Error Warning */}
          {data.error && (
            <div className="api-error">
              <span className="api-error-icon">⚠</span>
              <span className="api-error-text">{data.error}</span>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function RefreshIcon({ spinning }: { spinning: boolean }) {
  return (
    <svg
      className={`refresh-icon ${spinning ? "spinning" : ""}`}
      width="14"
      height="14"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M21 12a9 9 0 0 0-9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" />
      <path d="M3 3v5h5" />
      <path d="M3 12a9 9 0 0 0 9 9 9.75 9.75 0 0 0 6.74-2.74L21 16" />
      <path d="M21 21v-5h-5" />
    </svg>
  );
}
