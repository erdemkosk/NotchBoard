import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var updater = UpdateService.shared

    var body: some View {
        Form {
            Section {
                updateRow
            }

            Section {
                Toggle(L.launchAtLogin, isOn: $settings.launchAtLogin)

                VStack(alignment: .leading, spacing: 2) {
                    Toggle(L.autoPaste, isOn: $settings.autoPaste)
                    Text(L.autoPasteHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle(L.skipSensitive, isOn: $settings.skipSensitive)
            }

            Section {
                Stepper(value: $settings.maxItems, in: 20...500, step: 10) {
                    HStack {
                        Text(L.maxItems)
                        Spacer()
                        Text("\(settings.maxItems)").foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                HStack {
                    Image(systemName: "keyboard")
                    Text(L.hotkeyHint)
                    Spacer()
                }
                .foregroundStyle(.secondary)
            }

            Section(L.about) {
                aboutRow
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 520)
    }

    private var aboutRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(L.developedWithLove)
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                Text(L.t("by", "·"))
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)

            Text(L.developer)
                .font(.system(size: 16, weight: .semibold))

            Button {
                NSWorkspace.shared.open(AppInfo.releasesURL)
            } label: {
                Label(L.viewOnGitHub, systemImage: "link")
                    .font(.caption)
            }
            .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var updateRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("NotchBoard")
                    .font(.headline)
                Text("\(L.version) \(AppInfo.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                updateStatusText
            }
            Spacer()
            updateButton
        }
    }

    @ViewBuilder
    private var updateStatusText: some View {
        switch updater.state {
        case .upToDate:
            Text(L.upToDate).font(.caption).foregroundStyle(.green)
        case .available(let v):
            Text(L.updateAvailable(v)).font(.caption).foregroundStyle(.orange)
        case .failed(let msg):
            Text(msg).font(.caption).foregroundStyle(.red).lineLimit(2)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var updateButton: some View {
        switch updater.state {
        case .checking:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text(L.checking) }
        case .downloading:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text(L.downloading) }
        case .installing:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text(L.installing) }
        case .available:
            Button(L.restartToUpdate) { updater.downloadAndInstall() }
                .buttonStyle(.borderedProminent)
        default:
            Button(L.checkForUpdates) { updater.checkForUpdates() }
        }
    }
}
