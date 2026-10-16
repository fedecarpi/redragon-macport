import Foundation
import IOKit.hid

enum HIDError: LocalizedError {
    case notFound
    case openFailed
    case writeFailed(Int32)
    case disconnected

    var errorDescription: String? {
        switch self {
        case .notFound: return "No compatible Redragon/EVision keyboard found (VID 0x0C45 PID 0x5004)."
        case .openFailed: return "Could not open the HID device."
        case .writeFailed(let c): return "HID write failed (IOReturn \(c))."
        case .disconnected: return "Keyboard disconnected."
        }
    }
}

final class HIDDeviceManager {
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?

    var connectedIdentity: KeyboardIdentity?

    deinit {
        close()
    }

    func refresh() throws -> KeyboardIdentity {
        close()

        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = mgr

        var matching: [[String: Any]] = []
        for cand in KeyboardIdentity.k589Candidates {
            matching.append([
                kIOHIDVendorIDKey as String: cand.vid,
                kIOHIDProductIDKey as String: cand.pid
            ])
        }
        IOHIDManagerSetDeviceMatchingMultiple(mgr, matching as CFArray)
        let open = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        guard open == kIOReturnSuccess else { throw HIDError.openFailed }

        guard let set = IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice> else {
            throw HIDError.notFound
        }

        // Prefer usage page 0xFF1C vendor interface when present (OpenRGB detector).
        let preferred = set.first { device in
            let page = IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? 0
            return page == 0xFF1C
        } ?? set.first

        guard let preferred else { throw HIDError.notFound }

        let vid = IOHIDDeviceGetProperty(preferred, kIOHIDVendorIDKey as CFString) as? Int ?? 0
        let pid = IOHIDDeviceGetProperty(preferred, kIOHIDProductIDKey as CFString) as? Int ?? 0
        let product = IOHIDDeviceGetProperty(preferred, kIOHIDProductKey as CFString) as? String ?? "Keyboard"
        let path = IOHIDDeviceGetProperty(preferred, kIOHIDLocationIDKey as CFString).map { "\($0)" } ?? "unknown"

        let result = IOHIDDeviceOpen(preferred, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        if result != kIOReturnSuccess {
            // Fallback without seize (macOS often keeps keyboard input claimed).
            let soft = IOHIDDeviceOpen(preferred, IOOptionBits(kIOHIDOptionsTypeNone))
            guard soft == kIOReturnSuccess else { throw HIDError.openFailed }
        }

        device = preferred
        let identity = KeyboardIdentity(vendorID: vid, productID: pid, product: product, path: path)
        connectedIdentity = identity
        return identity
    }

    func close() {
        if let device {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        if let manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        device = nil
        manager = nil
        connectedIdentity = nil
    }

    func writeReport(_ bytes: [UInt8]) throws {
        guard let device else { throw HIDError.disconnected }
        var mutable = bytes
        let count = mutable.count
        let kr = mutable.withUnsafeMutableBytes { raw -> IOReturn in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else {
                return kIOReturnError
            }
            return IOHIDDeviceSetReport(
                device,
                kIOHIDReportTypeOutput,
                CFIndex(EVisionProtocol.reportID),
                base,
                count
            )
        }
        if kr != kIOReturnSuccess {
            // Some firmwares accept feature reports instead of output.
            let kr2 = mutable.withUnsafeMutableBytes { raw -> IOReturn in
                guard let base = raw.bindMemory(to: UInt8.self).baseAddress else {
                    return kIOReturnError
                }
                return IOHIDDeviceSetReport(
                    device,
                    kIOHIDReportTypeFeature,
                    CFIndex(EVisionProtocol.reportID),
                    base,
                    count
                )
            }
            guard kr2 == kIOReturnSuccess else { throw HIDError.writeFailed(kr) }
        }
    }

    func applyModeEx(
        mode: UInt8,
        brightness: UInt8,
        speed: UInt8,
        direction: UInt8,
        random: UInt8,
        color: (UInt8, UInt8, UInt8)
    ) throws {
        try writeReport(EVisionProtocol.beginPacket())
        try writeReport(
            EVisionProtocol.modeExPacket(
                mode: mode,
                brightness: min(brightness, 4),
                speed: min(speed, 5),
                direction: direction,
                random: random,
                red: color.0,
                green: color.1,
                blue: color.2
            )
        )
        try writeReport(EVisionProtocol.endPacket())
    }

    func setPollingRate(_ rateCode: UInt8) throws {
        try writeReport(EVisionProtocol.beginPacket())
        try writeReport(EVisionProtocol.parameterPacket(parameter: .pollingRate, data: [rateCode]))
        try writeReport(EVisionProtocol.endPacket())
    }

    /// Upload a profile/macro table via cmd `0x08` (`sub_441d80`).
    /// `profileStride` defaults to `payload.count` when unknown (matches many EVision builds).
    func writeBulkProfile(
        _ payload: [UInt8],
        profileSlot: Int,
        profileStride: Int? = nil,
        command: EVisionProtocol.Command = .writeBulk08
    ) throws {
        let stride = profileStride ?? payload.count
        for packet in EVisionProtocol.bulkPackets(
            command: command,
            payload: payload,
            profileSlot: profileSlot,
            profileStride: stride
        ) {
            try writeReport(packet)
        }
    }

}
