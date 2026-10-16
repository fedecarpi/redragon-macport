# Redragon K589 — macOS config

Unofficial macOS port of the Redragon K589RGB (EVision) keyboard configurator.

Connect a compatible board (**VID `0x0C45` / PID `0x5004`**), pick a lighting mode, and apply settings over HID.

> Not affiliated with Redragon. Use at your own risk. The binary from GitHub Actions is **ad-hoc signed** (not Apple-notarized); on first open use right-click → Open if Gatekeeper blocks it.

## Download

GitHub Actions builds a universal `.app` and attaches it to [Releases](https://github.com/fedecarpi/redragon-macport/releases).

- **Automatic:** push a tag `v0.1.0` (or any `v*`)
- **Manual:** Actions → **Release** → Run workflow → enter version `0.1.0`

Artifact: `K589Config-<version>-macos-universal.zip`

## Build locally (needs Xcode / CLT + Swift 5.9+)

```bash
swift build -c release
swift run

# or package a .app
VERSION=0.1.0 ./scripts/package-app.sh
open dist/K589Config.app
```

Requires **macOS 14+**.

## Layout

| Path | Purpose |
|------|---------|
| `Sources/K589Config/` | SwiftUI app + IOKit HID + EVision framing |
| `docs/HID_PROTOCOL.md` | HID packet notes recovered from the Windows tool |
| `scripts/package-app.sh` | Build + wrap `.app` + zip |
| `.github/workflows/` | CI build + Release publish |

## Protocol notes

See [docs/HID_PROTOCOL.md](docs/HID_PROTOCOL.md). Lighting modes map to the EVision command set also used by OpenRGB.
