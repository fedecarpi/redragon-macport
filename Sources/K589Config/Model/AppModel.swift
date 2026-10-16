import AppKit
import Combine
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var status: String = "Connect a Redragon K589 (0x0C45:0x5004)."
    @Published var identity: KeyboardIdentity?
    @Published var selectedMode: LightingMode = LightingMode.all.first { $0.id == 6 }!
    @Published var profile: Int = 1
    @Published var brightness: Double = 4
    @Published var speed: Double = 3
    @Published var direction: WaveDirection = .right
    @Published var color: Color = .red
    @Published var randomColor: Bool = false
    @Published var pollingRate: Int = 3 // 1000 Hz
    @Published var lastError: String?

    private let hid = HIDDeviceManager()

    func connect() {
        do {
            let id = try hid.refresh()
            identity = id
            status = "Connected: \(id.product) (\(String(format: "%04X:%04X", id.vendorID, id.productID)))"
            lastError = nil
        } catch {
            identity = nil
            status = "Not connected"
            lastError = error.localizedDescription
        }
    }

    func disconnect() {
        hid.close()
        identity = nil
        status = "Disconnected"
    }

    func apply() {
        guard identity != nil else {
            lastError = HIDError.notFound.errorDescription
            return
        }
        let ns = NSColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        do {
            try hid.applyModeEx(
                mode: selectedMode.protocolByte,
                brightness: UInt8(brightness.rounded()),
                speed: UInt8((5 - speed).rounded()), // UI fast→slow maps to protocol 0…5
                direction: selectedMode.supportsDirection ? direction.rawValue : 0,
                random: randomColor ? 1 : 0,
                color: (UInt8(r * 255), UInt8(g * 255), UInt8(b * 255))
            )
            status = "Applied \(selectedMode.title) · profile \(profile)"
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func applyPollingRate() {
        do {
            try hid.setPollingRate(UInt8(pollingRate))
            status = "USB report rate updated"
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
