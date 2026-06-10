import SwiftUI
import AppKit
import Carbon.HIToolbox

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var updater = UpdateService.shared

    private static let keyOptions: [(name: String, code: Int)] = [
        ("A", kVK_ANSI_A), ("B", kVK_ANSI_B), ("C", kVK_ANSI_C), ("D", kVK_ANSI_D),
        ("E", kVK_ANSI_E), ("F", kVK_ANSI_F), ("G", kVK_ANSI_G), ("H", kVK_ANSI_H),
        ("I", kVK_ANSI_I), ("J", kVK_ANSI_J), ("K", kVK_ANSI_K), ("L", kVK_ANSI_L),
        ("M", kVK_ANSI_M), ("N", kVK_ANSI_N), ("O", kVK_ANSI_O), ("P", kVK_ANSI_P),
        ("Q", kVK_ANSI_Q), ("R", kVK_ANSI_R), ("S", kVK_ANSI_S), ("T", kVK_ANSI_T),
        ("U", kVK_ANSI_U), ("V", kVK_ANSI_V), ("W", kVK_ANSI_W), ("X", kVK_ANSI_X),
        ("Y", kVK_ANSI_Y), ("Z", kVK_ANSI_Z),
        ("0", kVK_ANSI_0), ("1", kVK_ANSI_1), ("2", kVK_ANSI_2), ("3", kVK_ANSI_3),
        ("4", kVK_ANSI_4), ("5", kVK_ANSI_5), ("6", kVK_ANSI_6), ("7", kVK_ANSI_7),
        ("8", kVK_ANSI_8), ("9", kVK_ANSI_9),
        ("Space", kVK_Space), ("Return", kVK_Return), ("Tab", kVK_Tab), ("Esc", kVK_Escape)
    ]

    var body: some View {
        Form {
            Section {
                updateRow
            }

            Section {
                Toggle(L.launchAtLogin, isOn: $settings.launchAtLogin)
                Toggle(L.skipSensitive, isOn: $settings.skipSensitive)
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(L.autoPaste, isOn: $settings.autoPasteEnabled)
                    Text(L.autoPasteHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(L.captureHUD, isOn: $settings.captureHUDEnabled)
                    Text(L.captureHUDHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(L.hideFromScreenCapture, isOn: $settings.hideFromScreenCapture)
                    Text(L.hideFromScreenCaptureHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Stepper(value: $settings.maxItems, in: 20...500, step: 10) {
                    HStack {
                        Text(L.maxItems)
                        Spacer()
                        Text("\(settings.maxItems)").foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Picker(L.autoDelete, selection: $settings.autoDeleteMinutes) {
                        ForEach(AppSettings.retentionOptions, id: \.self) { minutes in
                            Text(L.retentionLabel(minutes)).tag(minutes)
                        }
                    }
                    Text(L.autoDeleteHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                pillPreview
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(L.pillWidth)
                        Spacer()
                        Text("\(Int(settings.triggerPillWidth)) pt").foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $settings.triggerPillWidth,
                        in: AppSettings.minPillWidth...AppSettings.maxPillWidth,
                        step: 5
                    )
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(L.pillHeight)
                        Spacer()
                        Text("\(Int(settings.triggerPillHeight)) pt").foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $settings.triggerPillHeight,
                        in: AppSettings.minPillHeight...AppSettings.maxPillHeight,
                        step: 1
                    )
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(L.pillCorner)
                        Spacer()
                        Text("\(Int(settings.triggerPillCornerRadius)) pt").foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $settings.triggerPillCornerRadius,
                        in: AppSettings.minPillCorner...AppSettings.maxPillCorner,
                        step: 1
                    )
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(L.t("Horizontal Position", "Yatay Konum"))
                        Spacer()
                        if settings.horizontalOffset != 0 {
                            Button(L.t("Reset", "Sıfırla")) {
                                settings.horizontalOffset = 0
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                        Text("\(Int(settings.horizontalOffset)) pt").foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $settings.horizontalOffset,
                        in: -400...400,
                        step: 5
                    )
                }
                Text(L.pillHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(L.triggerPillSection)
            }

            Section(L.keyboardShortcut) {
                HStack(spacing: 12) {
                    Toggle("⌘ Cmd", isOn: Binding(
                        get: { (settings.hotkeyModifiers & cmdKey) != 0 },
                        set: { value in
                            if value { settings.hotkeyModifiers |= cmdKey }
                            else { settings.hotkeyModifiers &= ~cmdKey }
                        }
                    ))
                    Toggle("⇧ Shift", isOn: Binding(
                        get: { (settings.hotkeyModifiers & shiftKey) != 0 },
                        set: { value in
                            if value { settings.hotkeyModifiers |= shiftKey }
                            else { settings.hotkeyModifiers &= ~shiftKey }
                        }
                    ))
                    Toggle("⌥ Opt", isOn: Binding(
                        get: { (settings.hotkeyModifiers & optionKey) != 0 },
                        set: { value in
                            if value { settings.hotkeyModifiers |= optionKey }
                            else { settings.hotkeyModifiers &= ~optionKey }
                        }
                    ))
                    Toggle("⌃ Ctrl", isOn: Binding(
                        get: { (settings.hotkeyModifiers & controlKey) != 0 },
                        set: { value in
                            if value { settings.hotkeyModifiers |= controlKey }
                            else { settings.hotkeyModifiers &= ~controlKey }
                        }
                    ))
                }
                .toggleStyle(.checkbox)

                Picker(L.t("Key", "Tuş"), selection: $settings.hotkeyCode) {
                    ForEach(Self.keyOptions, id: \.code) { option in
                        Text(option.name).tag(option.code)
                    }
                }
            }

            Section(L.about) {
                aboutRow
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 760)
    }

    private var pillPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.85))
                .frame(height: 64)
            UnevenRoundedRectangle(
                bottomLeadingRadius: settings.triggerPillCornerRadius,
                bottomTrailingRadius: settings.triggerPillCornerRadius
            )
            .fill(Color.white)
            .frame(
                width: min(settings.triggerPillWidth, 360),
                height: settings.triggerPillHeight
            )
            .frame(maxHeight: 64, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.15), value: settings.triggerPillWidth)
        .animation(.easeOut(duration: 0.15), value: settings.triggerPillHeight)
        .animation(.easeOut(duration: 0.15), value: settings.triggerPillCornerRadius)
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

            HStack(spacing: 16) {
                Button {
                    NSWorkspace.shared.open(AppInfo.releasesURL)
                } label: {
                    Label(L.viewOnGitHub, systemImage: "link")
                        .font(.caption)
                }
                .buttonStyle(.link)

                Button {
                    NSWorkspace.shared.open(AppInfo.websiteURL)
                } label: {
                    Label(L.visitWebsite, systemImage: "globe")
                        .font(.caption)
                }
                .buttonStyle(.link)
            }
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
