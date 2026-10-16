import Foundation
import SwiftUI

/// Lighting modes from Windows `Files1/Main.ini` `[Mode]`, mapped to EVision protocol bytes.
/// Names are observations from the shipped installer payload; protocol bytes match OpenRGB EVision.
struct LightingMode: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let protocolByte: UInt8
    let supportsDirection: Bool
    let supportsColor: Bool

    static let all: [LightingMode] = [
        .init(id: 1, title: "Go with the stream", protocolByte: 0x01, supportsDirection: true, supportsColor: false),
        .init(id: 2, title: "Clouds fly", protocolByte: 0x02, supportsDirection: true, supportsColor: false),
        .init(id: 3, title: "Winding paths", protocolByte: 0x03, supportsDirection: true, supportsColor: false),
        .init(id: 4, title: "The trial of light", protocolByte: 0x04, supportsDirection: false, supportsColor: false),
        .init(id: 5, title: "Breathing", protocolByte: 0x05, supportsDirection: false, supportsColor: true),
        .init(id: 6, title: "Normally on", protocolByte: 0x06, supportsDirection: false, supportsColor: true),
        .init(id: 7, title: "Pass without trace", protocolByte: 0x07, supportsDirection: false, supportsColor: true),
        .init(id: 8, title: "Ripple graff", protocolByte: 0x08, supportsDirection: false, supportsColor: true),
        .init(id: 9, title: "Fast run without trace", protocolByte: 0x09, supportsDirection: false, supportsColor: true),
        // UI 10/11/12 poetic names are shuffled vs protocol (REA + OpenRGB cross-check)
        .init(id: 10, title: "Snow winter jasmine", protocolByte: 0x0C, supportsDirection: true, supportsColor: false),
        .init(id: 11, title: "Flowers blooming", protocolByte: 0x0B, supportsDirection: false, supportsColor: false),
        .init(id: 12, title: "Swift action", protocolByte: 0x0A, supportsDirection: false, supportsColor: true),
        .init(id: 13, title: "Hurricane", protocolByte: 0x0D, supportsDirection: false, supportsColor: false),
        .init(id: 14, title: "Accumulate", protocolByte: 0x0E, supportsDirection: false, supportsColor: false),
        .init(id: 15, title: "Digital Times", protocolByte: 0x0F, supportsDirection: false, supportsColor: true),
        .init(id: 16, title: "Both ways", protocolByte: 0x10, supportsDirection: false, supportsColor: true),
        .init(id: 17, title: "Surmount", protocolByte: 0x11, supportsDirection: false, supportsColor: true),
        .init(id: 18, title: "Fast and the Furious", protocolByte: 0x12, supportsDirection: false, supportsColor: false),
        .init(id: 20, title: "Coastal (custom)", protocolByte: 0x14, supportsDirection: false, supportsColor: false)
    ]
}

enum WaveDirection: UInt8, CaseIterable, Identifiable {
    case left = 0xFF
    case right = 0x00

    var id: UInt8 { rawValue }

    var title: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}

struct KeyboardIdentity: Hashable, Sendable {
    let vendorID: Int
    let productID: Int
    let product: String
    let path: String

    /// Primary IDs recovered from FwCustom init immediates / OpenRGB K589 registration.
    static let k589Candidates: [(vid: Int, pid: Int, label: String)] = [
        (0x0C45, 0x5004, "Redragon K589 / K556 (0x0C45:0x5004)"),
        (0x320F, 0x5000, "EVision-compatible (0x320F:0x5000)")
    ]
}
