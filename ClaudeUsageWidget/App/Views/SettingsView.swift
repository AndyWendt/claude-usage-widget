import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval: Int = 300
    @State private var launchAtLogin: Bool = false
    @ObservedObject var manager: UsageManager

    var onIntervalChanged: ((Int) -> Void)?

    private let intervalOptions: [(String, Int)] = [
        ("1 min", 60),
        ("2 min", 120),
        ("5 min", 300),
        ("10 min", 600),
        ("15 min", 900),
    ]

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Refresh interval:")
                    .font(.system(size: 11))
                    .foregroundStyle(AnthropicColors.creamMuted)
                Spacer()
                Picker("", selection: $refreshInterval) {
                    ForEach(intervalOptions, id: \.1) { label, value in
                        Text(label).tag(value)
                    }
                }
                .labelsHidden()
                .frame(width: 80)
                .onChange(of: refreshInterval) { _, newValue in
                    onIntervalChanged?(newValue)
                }
            }

            HStack {
                Text("Launch at login:")
                    .font(.system(size: 11))
                    .foregroundStyle(AnthropicColors.creamMuted)
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .onChange(of: launchAtLogin) { _, newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Pace indicator:")
                    .font(.system(size: 11))
                    .foregroundStyle(AnthropicColors.creamMuted)
                Toggle("5-Hour Window", isOn: paceBinding(for: .fiveHour))
                    .font(.system(size: 11))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                Toggle("Weekly (All)", isOn: paceBinding(for: .sevenDay))
                    .font(.system(size: 11))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                Toggle("Weekly (Sonnet)", isOn: paceBinding(for: .sevenDaySonnet))
                    .font(.system(size: 11))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                Toggle("Weekly (Opus)", isOn: paceBinding(for: .sevenDayOpus))
                    .font(.system(size: 11))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 11))
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func paceBinding(for metric: MetricKey) -> Binding<Bool> {
        Binding(
            get: { manager.paceSettings.enabledMetrics.contains(metric) },
            set: { enabled in
                var metrics = manager.paceSettings.enabledMetrics
                if enabled {
                    metrics.insert(metric)
                } else {
                    metrics.remove(metric)
                }
                manager.updatePaceSettings(PaceSettings(enabledMetrics: metrics))
            }
        )
    }

    private func toggleLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
