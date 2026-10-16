import AppKit
import SwiftUI

/// Local lighting simulation over the Windows keyboard skin (`Main.ini` key rects).
/// Approximates FwCustom's timer-painted preview — not a pixel-perfect decompile of each mode painter.
struct KeyboardPreview: View {
    let mode: LightingMode
    let brightness: Double
    let speed: Double
    let direction: WaveDirection
    let color: Color
    let colourful: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let scale = min(
                    geo.size.width / KeyboardLayout.skinSize.width,
                    geo.size.height / KeyboardLayout.skinSize.height
                )
                let drawSize = CGSize(
                    width: KeyboardLayout.skinSize.width * scale,
                    height: KeyboardLayout.skinSize.height * scale
                )
                let origin = CGPoint(
                    x: (geo.size.width - drawSize.width) / 2,
                    y: (geo.size.height - drawSize.height) / 2
                )

                ZStack(alignment: .topLeading) {
                    if let nsImage = NSImage(named: "keyboard_skin")
                        ?? Bundle.module.image(forResource: "keyboard_skin") {
                        Image(nsImage: nsImage)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: drawSize.width, height: drawSize.height)
                            .position(
                                x: origin.x + drawSize.width / 2,
                                y: origin.y + drawSize.height / 2
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.55))
                            .frame(width: drawSize.width, height: drawSize.height)
                            .position(
                                x: origin.x + drawSize.width / 2,
                                y: origin.y + drawSize.height / 2
                            )
                    }

                    Canvas { ctx, _ in
                        let phase = t * animationRate
                        let dirSign: Double = direction == .left ? -1 : 1
                        let bright = 0.22 + (brightness / 4.0) * 0.78

                        for (index, key) in KeyboardLayout.keys.enumerated() {
                            let nx = key.rect.midX / KeyboardLayout.skinSize.width
                            let ny = key.rect.midY / KeyboardLayout.skinSize.height
                            let intensity = effectIntensity(
                                modeID: mode.id,
                                nx: nx,
                                ny: ny,
                                index: index,
                                phase: phase,
                                dirSign: dirSign
                            )
                            guard intensity > 0.02 else { continue }

                            var led = ledColor(nx: nx, ny: ny, phase: phase, index: index)
                            led = led.opacity(intensity * bright)

                            let rect = CGRect(
                                x: origin.x + key.rect.minX * scale,
                                y: origin.y + key.rect.minY * scale,
                                width: key.rect.width * scale,
                                height: key.rect.height * scale
                            ).insetBy(dx: 0.5, dy: 0.5)

                            let path = Path(roundedRect: rect, cornerRadius: 2.5 * scale)
                            ctx.fill(path, with: .color(led))
                            ctx.stroke(path, with: .color(led.opacity(0.35)), lineWidth: 0.6)
                        }
                    }
                }
            }
        }
        .aspectRatio(
            KeyboardLayout.skinSize.width / KeyboardLayout.skinSize.height,
            contentMode: .fit
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.red.opacity(0.12), radius: 18, y: 8)
    }

    /// UI speed 0…5 (slow→fast) → phase multiplier.
    private var animationRate: Double {
        0.35 + (speed / 5.0) * 2.4
    }

    private func ledColor(nx: Double, ny: Double, phase: Double, index: Int) -> Color {
        if colourful || !mode.supportsColor {
            let hue = (nx * 0.55 + ny * 0.25 + phase * 0.08 + Double(index % 17) * 0.01)
                .truncatingRemainder(dividingBy: 1)
            return Color(hue: hue < 0 ? hue + 1 : hue, saturation: 0.85, brightness: 1)
        }
        return color
    }

    private func effectIntensity(
        modeID: Int,
        nx: Double,
        ny: Double,
        index: Int,
        phase: Double,
        dirSign: Double
    ) -> Double {
        switch modeID {
        case 1: // Go with the stream — horizontal wave
            return band(nx * dirSign + phase * 0.35, width: 0.22)
        case 2: // Clouds fly — soft drifting bands
            return soft((sin((nx * 4 + ny * 1.2) * .pi + phase) + 1) / 2, floor: 0.15)
        case 3: // Winding paths — diagonal
            return band((nx + ny) * dirSign + phase * 0.3, width: 0.2)
        case 4: // Trial of light — vertical sweep
            return band(ny + phase * 0.4, width: 0.18)
        case 5: // Breathing
            return soft((sin(phase * 1.2) + 1) / 2, floor: 0.08)
        case 6: // Normally on
            return 1
        case 7: // Pass without trace — single traveling pulse
            return band(nx * dirSign + phase * 0.55, width: 0.08)
        case 8: // Ripple — radial
            let d = hypot(nx - 0.45, ny - 0.55)
            return band(d * 2.2 - phase * 0.5, width: 0.16)
        case 9: // Fast run without trace
            return band(nx * dirSign + phase * 0.9, width: 0.1)
        case 10: // Snow — twinkles
            let spark = sin(Double(index) * 12.9898 + phase * 3)
            return spark > 0.72 ? soft(spark, floor: 0) : 0.05
        case 11: // Flowers blooming — expanding bursts
            let centers = [(0.25, 0.4), (0.55, 0.55), (0.75, 0.35)]
            let c = centers[index % centers.count]
            let d = hypot(nx - c.0, ny - c.1)
            let bloom = (sin(phase + Double(index % 3)) + 1) / 2
            return max(0, 1 - abs(d - bloom * 0.45) * 4)
        case 12: // Swift action — strobe rows
            return (Int((phase * 6) + ny * 8) % 2 == 0) ? 1 : 0.12
        case 13: // Hurricane — rotating spiral
            let ang = atan2(ny - 0.55, nx - 0.48)
            let d = hypot(nx - 0.48, ny - 0.55)
            return band((ang / .pi) + d * 2 + phase * 0.4, width: 0.2)
        case 14: // Accumulate — fill from bottom
            let fill = (sin(phase * 0.5) + 1) / 2
            return ny > (1 - fill) ? soft(1 - (ny - (1 - fill)) * 3, floor: 0.1) : 0.04
        case 15: // Digital Times — column rain
            let col = floor(nx * 18)
            let drop = (phase * 0.7 + col * 0.37).truncatingRemainder(dividingBy: 1)
            return max(0, 1 - abs(ny - drop) * 5)
        case 16: // Both ways — dual counter waves
            let a = band(nx + phase * 0.35, width: 0.14)
            let b = band(-nx + phase * 0.35, width: 0.14)
            return max(a, b)
        case 17: // Surmount — climb columns
            return band(ny * dirSign + phase * 0.45, width: 0.16)
        case 18: // Fast and the Furious — noisy flash
            return soft(abs(sin(phase * 2 + Double(index) * 0.4)), floor: 0.1)
        case 20: // Coastal / custom — gentle shore wash
            return soft((sin(nx * 3 + phase * 0.5) * 0.5 + 0.5) * (0.4 + ny * 0.6), floor: 0.1)
        default:
            return 0.6
        }
    }

    private func band(_ x: Double, width: Double) -> Double {
        let f = x.truncatingRemainder(dividingBy: 1)
        let u = f < 0 ? f + 1 : f
        let d = min(u, 1 - u)
        return max(0, 1 - d / width)
    }

    private func soft(_ v: Double, floor: Double) -> Double {
        floor + (1 - floor) * min(1, max(0, v))
    }
}

private extension Bundle {
    func image(forResource name: String) -> NSImage? {
        if let url = url(forResource: name, withExtension: "jpg")
            ?? url(forResource: name, withExtension: "jpeg")
            ?? url(forResource: name, withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}
