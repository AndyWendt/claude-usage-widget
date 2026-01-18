interface TokenStatsProps {
  stats: {
    todayTokens: number;
    weekTokens: number;
    todayMessages: number;
    weekMessages: number;
  };
}

export function TokenStats({ stats }: TokenStatsProps) {
  const formatNumber = (count: number): string => {
    if (count >= 1_000_000) {
      return `${(count / 1_000_000).toFixed(1)}M`;
    }
    if (count >= 1_000) {
      return `${(count / 1_000).toFixed(0)}K`;
    }
    return count.toLocaleString();
  };

  return (
    <div className="token-stats">
      <div className="token-stat">
        <span className="token-label">Today:</span>
        <span className="token-value">
          {formatNumber(stats.todayTokens)} tokens
        </span>
      </div>
      <div className="token-stat">
        <span className="token-label">This week:</span>
        <span className="token-value">
          {formatNumber(stats.weekTokens)} tokens
        </span>
      </div>
    </div>
  );
}
