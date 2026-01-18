import { useState, useEffect, useCallback, useRef } from "react";
import { invoke } from "@tauri-apps/api/core";

export interface UsageMetric {
  percent: number;
  resetsAt: string;
}

export interface TokenStats {
  todayTokens: number;
  weekTokens: number;
  todayMessages: number;
  weekMessages: number;
}

export interface WidgetData {
  fiveHour: UsageMetric | null;
  sevenDay: UsageMetric | null;
  sevenDaySonnet: UsageMetric | null;
  sevenDayOpus: UsageMetric | null;
  tokenStats: TokenStats;
  lastUpdated: string;
  error: string | null;
}

interface UseUsageDataResult {
  data: WidgetData | null;
  loading: boolean;
  error: string | null;
  refresh: () => void;
}

const DEFAULT_REFRESH_INTERVAL = 60_000; // 60 seconds

export function useUsageData(): UseUsageDataResult {
  const [data, setData] = useState<WidgetData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const intervalRef = useRef<number | null>(null);

  const fetchData = useCallback(async () => {
    try {
      setLoading(true);
      const result = await invoke<WidgetData>("get_usage_data");
      setData(result);
      setError(result.error || null);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  const refresh = useCallback(() => {
    fetchData();
  }, [fetchData]);

  useEffect(() => {
    // Initial fetch
    fetchData();

    // Set up polling interval
    intervalRef.current = window.setInterval(fetchData, DEFAULT_REFRESH_INTERVAL);

    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, [fetchData]);

  return { data, loading, error, refresh };
}
