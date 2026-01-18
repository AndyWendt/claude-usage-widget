import { useState, useEffect } from "react";

interface ResetTimerProps {
  resetsAt: string;
}

export function ResetTimer({ resetsAt }: ResetTimerProps) {
  const [timeRemaining, setTimeRemaining] = useState("");

  useEffect(() => {
    const calculateTimeRemaining = () => {
      const resetTime = new Date(resetsAt).getTime();
      const now = Date.now();
      const diff = resetTime - now;

      if (diff <= 0) {
        setTimeRemaining("Resetting...");
        return;
      }

      const days = Math.floor(diff / (1000 * 60 * 60 * 24));
      const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
      const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));

      let result = "Resets in ";
      if (days > 0) {
        result += `${days}d ${hours}h`;
      } else if (hours > 0) {
        result += `${hours}h ${minutes}m`;
      } else {
        result += `${minutes}m`;
      }

      setTimeRemaining(result);
    };

    // Initial calculation
    calculateTimeRemaining();

    // Update every minute
    const interval = setInterval(calculateTimeRemaining, 60_000);

    return () => clearInterval(interval);
  }, [resetsAt]);

  return <div className="reset-timer">{timeRemaining}</div>;
}
