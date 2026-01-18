import { useEffect, useState } from "react";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { listen } from "@tauri-apps/api/event";
import { UsageWidget } from "./components/UsageWidget";
import { useUsageData } from "./hooks/useUsageData";

function App() {
  const { data, loading, error, refresh } = useUsageData();
  const [isDragging, setIsDragging] = useState(false);

  useEffect(() => {
    // Listen for tray menu events
    const unlistenRefresh = listen("refresh-usage", () => {
      refresh();
    });

    const unlistenToggle = listen("toggle-always-on-top", async () => {
      const window = getCurrentWindow();
      const isOnTop = await window.isAlwaysOnTop();
      await window.setAlwaysOnTop(!isOnTop);
    });

    return () => {
      unlistenRefresh.then((fn) => fn());
      unlistenToggle.then((fn) => fn());
    };
  }, [refresh]);

  // Handle window dragging - allow from anywhere except interactive elements
  const handleMouseDown = async (e: React.MouseEvent) => {
    const target = e.target as HTMLElement;
    // Don't start drag on buttons or other interactive elements
    if (target.closest("button, a, input, [data-no-drag]")) {
      return;
    }
    setIsDragging(true);
    await getCurrentWindow().startDragging();
  };

  const handleMouseUp = () => {
    setIsDragging(false);
  };

  return (
    <div
      className="widget-container"
      onMouseDown={handleMouseDown}
      onMouseUp={handleMouseUp}
    >
      <UsageWidget
        data={data}
        loading={loading}
        error={error}
        onRefresh={refresh}
        isDragging={isDragging}
      />
    </div>
  );
}

export default App;
