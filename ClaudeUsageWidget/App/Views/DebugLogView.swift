import SwiftUI

struct DebugLogView: View {
    let onBack: () -> Void
    @State private var debugLogText = ""

    var body: some View {
        VStack(spacing: 0) {
            headerView

            VStack(spacing: 8) {
                actionRow

                ScrollView {
                    Text(debugLogText.isEmpty ? "(no logs - tap Refresh or Run Diagnostics)" : debugLogText)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(AnthropicColors.cream)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .background(AnthropicColors.charcoal.opacity(0.3))
                .cornerRadius(8)
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            refreshLogs()
        }
    }

    private var headerView: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AnthropicColors.tan)
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)

            Text("Debugger")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AnthropicColors.tan)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var actionRow: some View {
        HStack {
            Button("Refresh Logs", action: refreshLogs)
                .font(.system(size: 10))

            Button("Run Diagnostics") {
                DebugLogger.shared.dumpContainerDiagnostics(source: "App-Manual")
                refreshLogs()
            }
            .font(.system(size: 10))

            Button("Clear") {
                DebugLogger.shared.clearLogs()
                debugLogText = ""
            }
            .font(.system(size: 10))

            Spacer()

            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(debugLogText, forType: .string)
            }
            .font(.system(size: 10))
        }
    }

    private func refreshLogs() {
        debugLogText = DebugLogger.shared.readLogs()
    }
}
