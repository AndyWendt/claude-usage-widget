interface UsageBarProps {
  percent: number;
  variant?: "default" | "opus";
}

export function UsageBar({ percent, variant = "default" }: UsageBarProps) {
  // Determine color based on usage level
  const getColorClass = () => {
    if (percent >= 90) return "bar-danger";
    if (percent >= 70) return "bar-warning";
    return variant === "opus" ? "bar-opus" : "bar-accent";
  };

  // Ensure percent is within bounds
  const clampedPercent = Math.min(100, Math.max(0, percent));

  return (
    <div className="usage-bar-container">
      <div className="usage-bar-track">
        <div
          className={`usage-bar-fill ${getColorClass()}`}
          style={{ width: `${clampedPercent}%` }}
        />
      </div>
      <span className="usage-bar-label">{Math.round(percent)}%</span>
    </div>
  );
}
