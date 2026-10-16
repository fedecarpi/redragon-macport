import Foundation

/// HID framing recovered from FwCustom (Hopper) and cross-checked with OpenRGB EVision.
///
/// Evidence highlights:
/// - `sub_4416d0` / `sub_4415b0`: pad to 64 bytes, overlapped `WriteFile` (+ optional read/retry)
/// - `sub_441a80`: report ID `0x04`, checksum = sum(bytes[3..<64]) stored LE at [1],[2]
/// - `sub_441d80`: command `0x08` bulk upload, payload chunks of `0x38` starting at offset 8
/// - `sub_442040`: command `0x0A` bulk upload (same chunking)
/// - `sub_42f920` ("MAIN_PROMPT_DEFAULT"): uploads profile buffers via cmd `0x08` for slots 0..2
enum EVisionProtocol {
    static let reportID: UInt8 = 0x04
    static let packetSize = 64
    static let bulkChunkSize = 0x38

    enum Command: UInt8 {
        case begin = 0x01
        case end = 0x02
        /// Observed in `sub_441a80` (`mov dword [buf+3], 0x205` → cmd 0x05).
        case query = 0x05
        case setParameter = 0x06
        /// Bulk write used when applying default/macro key tables (`sub_441d80`).
        case writeBulk08 = 0x08
        /// Second bulk writer (`sub_442040`) — likely LED/custom map.
        case writeBulk0A = 0x0A
        case writeCustomColors = 0x11
    }

    enum Parameter: UInt8 {
        case mode = 0x00
        case brightness = 0x01
        case speed = 0x02
        case direction = 0x03
        case randomColor = 0x04
        case modeColor = 0x05
        case pollingRate = 0x0F
    }

    enum ReplyStatus: UInt8 {
        case ok = 0x00
        /// Treated as hard failure in FwCustom builders.
        case errorFF = 0xFF
        case errorFE = 0xFE
    }

    static func checksum(_ buffer: inout [UInt8]) {
        precondition(buffer.count == packetSize)
        var sum: UInt16 = 0
        for i in 3..<packetSize {
            sum &+= UInt16(buffer[i])
        }
        buffer[1] = UInt8(sum & 0xFF)
        buffer[2] = UInt8(sum >> 8)
    }

    static func blankPacket(command: UInt8) -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: packetSize)
        buf[0] = reportID
        buf[3] = command
        checksum(&buf)
        return buf
    }

    static func beginPacket() -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: packetSize)
        buf[0] = reportID
        buf[1] = Command.begin.rawValue
        buf[3] = Command.begin.rawValue
        return buf
    }

    static func endPacket() -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: packetSize)
        buf[0] = reportID
        buf[1] = Command.end.rawValue
        buf[3] = Command.end.rawValue
        return buf
    }

    static func parameterPacket(parameter: Parameter, data: [UInt8]) -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: packetSize)
        buf[0] = reportID
        buf[3] = Command.setParameter.rawValue
        buf[4] = UInt8(data.count)
        buf[5] = parameter.rawValue
        for (i, b) in data.enumerated() where i < 56 {
            buf[8 + i] = b
        }
        checksum(&buf)
        return buf
    }

    /// Bulk upload frame matching `sub_441d80` / `sub_442040` layout.
    ///
    /// Layout: `[0]=0x04 [3]=cmd [4]=len [5..6]=addr LE [7]=0 [8..]=payload`
    /// Address = `profileStride * profileSlot + chunkOffset` (globals `dword_6d8a2c` / slot).
    static func bulkPacket(
        command: Command,
        address: Int,
        chunk: [UInt8]
    ) -> [UInt8] {
        precondition(command == .writeBulk08 || command == .writeBulk0A)
        precondition(chunk.count <= bulkChunkSize)
        var buf = [UInt8](repeating: 0, count: packetSize)
        buf[0] = reportID
        buf[3] = command.rawValue
        buf[4] = UInt8(chunk.count)
        buf[5] = UInt8(address & 0xFF)
        buf[6] = UInt8((address >> 8) & 0xFF)
        buf[7] = 0
        for (i, b) in chunk.enumerated() {
            buf[8 + i] = b
        }
        checksum(&buf)
        return buf
    }

    static func modeExPacket(
        mode: UInt8,
        brightness: UInt8,
        speed: UInt8,
        direction: UInt8,
        random: UInt8,
        red: UInt8,
        green: UInt8,
        blue: UInt8
    ) -> [UInt8] {
        parameterPacket(
            parameter: .mode,
            data: [mode, brightness, speed, direction, random, red, green, blue]
        )
    }

    /// Split a profile/macro blob into 0x38-byte HID bulk packets (`sub_441d80`).
    /// - Parameters:
    ///   - profileSlot: 0..<3 (FwCustom rejects ≥3)
    ///   - profileStride: device address stride between slots (`dword_6d8a2c`; often == payload count)
    static func bulkPackets(
        command: Command,
        payload: [UInt8],
        profileSlot: Int,
        profileStride: Int
    ) -> [[UInt8]] {
        precondition((0..<3).contains(profileSlot))
        var packets: [[UInt8]] = []
        var offset = 0
        while offset < payload.count {
            let end = min(offset + bulkChunkSize, payload.count)
            let address = profileStride * profileSlot + offset
            packets.append(
                bulkPacket(
                    command: command,
                    address: address,
                    chunk: Array(payload[offset..<end])
                )
            )
            offset = end
        }
        return packets
    }
}

