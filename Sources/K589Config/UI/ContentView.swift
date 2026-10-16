import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.08, blue: 0.10),
                    Color(red: 0.12, green: 0.04, blue: 0.05),
                    Color(red: 0.05, green: 0.06, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                sidebar
                Divider().overlay(Color.white.opacity(0.12))
                mainPanel
            }
        }
        .frame(minWidth: 960, minHeight: 620)
        .onAppear { model.connect() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("REDRAGON")
                .font(.custom("Avenir Next Condensed", size: 34).weight(.heavy))
                .foregroundStyle(
                    LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                )
            Text("K589 RGB")
                .font(.custom("Avenir Next", size: 18).weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))

            Text(model.status)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)

            Group {
                labeled("Profile") {
                    Picker("Profile", selection: $model.profile) {
                        Text("Profile 1").tag(1)
                        Text("Profile 2").tag(2)
                        Text("Profile 3").tag(3)
                    }
                    .pickerStyle(.segmented)
                }

                labeled("Mode") {
                    Picker("Mode", selection: $model.selectedMode) {
                        ForEach(LightingMode.all) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }

                labeled("Brightness") {
                    Slider(value: $model.brightness, in: 0...4, step: 1)
                }

                labeled("Speed") {
                    Slider(value: $model.speed, in: 0...5, step: 1)
                }

                if model.selectedMode.supportsDirection {
                    labeled("Direction") {
                        Picker("Direction", selection: $model.direction) {
                            ForEach(WaveDirection.allCases) { dir in
                                Text(dir.title).tag(dir)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if model.selectedMode.supportsColor {
                    labeled("Color") {
                        HStack {
                            ColorPicker("Color", selection: $model.color, supportsOpacity: false)
                                .labelsHidden()
                            Toggle("Rainbow", isOn: $model.randomColor)
                                .toggleStyle(.switch)
                        }
                    }
                }

                labeled("USB report rate") {
                    Picker("Rate", selection: $model.pollingRate) {
                        Text("125 Hz").tag(0)
                        Text("250 Hz").tag(1)
                        Text("500 Hz").tag(2)
                        Text("1000 Hz").tag(3)
                    }
                    .onChange(of: model.pollingRate) { _, _ in
                        model.applyPollingRate()
                    }
                }
            }

            Spacer()

            if let err = model.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Refresh") { model.connect() }
                Button("Apply") { model.apply() }
                    .keyboardShortcut(.defaultAction)
                Button("Disconnect") { model.disconnect() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(24)
        .frame(width: 340)
        .background(Color.black.opacity(0.25))
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Official Windows driver surface (REA port)")
                .font(.custom("Avenir Next", size: 22).weight(.semibold))
                .foregroundStyle(.white)

            Text("Profiles, lighting modes, brightness, speed, direction, color, and USB report rate — recovered from InstallShield payload `FwCustom` + `Main.ini`, using the EVision HID framing also used by OpenRGB.")
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: 560, alignment: .leading)

            keyboardChrome

            Spacer()

            Text("Macros / per-key remaps from the Windows Composite dialog are not ported yet (needs Hopper/Ghidra decompilation once the REA Hopper session is healthy).")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var keyboardChrome: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.55), Color.red.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            VStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(0..<14, id: \.self) { col in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(keyFill(row: row, col: col))
                                .frame(width: keyWidth(row: row, col: col), height: 28)
                                .shadow(color: glowColor.opacity(0.55), radius: 6)
                        }
                    }
                }
            }
            .padding(28)
        }
        .frame(height: 260)
        .animation(.easeInOut(duration: 0.35), value: model.selectedMode.id)
        .animation(.easeInOut(duration: 0.25), value: model.color.description)
    }

    private var glowColor: Color {
        model.randomColor ? .purple : model.color
    }

    private func keyFill(row: Int, col: Int) -> Color {
        let base = glowColor.opacity(0.35 + Double((row + col) % 3) * 0.15)
        return base.opacity(0.25 + model.brightness / 4 * 0.75)
    }

    private func keyWidth(row: Int, col: Int) -> CGFloat {
        if row == 4 && col == 3 { return 90 }
        if row == 2 && col == 13 { return 52 }
        return 34
    }

    @ViewBuilder
    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.45))
            content()
        }
    }
}
