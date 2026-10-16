# FwCustom HID protocol (REA / Hopper)

Target: `_extracted/app/DefaultComponent/Redragon K589RGB.exe`  
SHA-256 `d634e919716bbaa03e049414efbfae29e82c9242a5bc6d63b36527f7abb3e9e0`

## Transport (observed)

| Step | Procedure | Notes |
|------|-----------|-------|
| Enumerate | `sub_401220` | `HidD_GetHidGuid` + `SetupDiGetClassDevsW` / `EnumDeviceInterfaces` |
| Caps | `sub_401450` | `HidD_GetPreparsedData`, `HidD_GetAttributes`, `HidP_GetCaps` |
| Write | `sub_4020b0` | Overlapped `WriteFile` on device handle |
| Send pad | `sub_4416d0` | Copy ≤64 bytes into stack buf, zero-pad, write exactly **64** |
| Request/response | `sub_4415b0` | Write + read (`sub_401ff0`), retry ≤4 |

`HidServ.dll` ships in the installer; this build talks **`hid.dll` / SetupAPI directly**.

## Frame layout (observed)

```
[0]     = 0x04          report ID
[1..2]  = checksum LE   sum(buf[3] .. buf[63])
[3]     = command
[4..]   = command payload
```

Checksum algorithm matches OpenRGB `EVisionKeyboardController::ComputeChecksum`  
(Evidence: `sub_441a80` asm stores `al`/`ah` into `[1]`/`[2]` after summing from offset 3).

## Commands seen in builders

| Cmd | Procedure | Role |
|-----|-----------|------|
| `0x05` | `sub_441a80` (`dword 0x205` at +3 → `05 02 00 00`) | Query / status (reply copies a `uint16`) |
| `0x06` | OpenRGB / port `setParameter` | Mode, brightness, speed, color, polling |
| `0x08` | `sub_441d80` | Bulk upload, **0x38**-byte chunks @ offset 8 |
| `0x0A` | `sub_442040` | Second bulk path (same chunking) |
| `0x01`/`0x02` | OpenRGB begin/end | Session framing used by lighting writers |

Reply status bytes checked by builders: **`0xFF`** / **`0xFE`** → error.

## Bulk cmd `0x08` frame (`sub_441d80`)

```
[0]     = 0x04
[1..2]  = checksum LE(sum[3..63])
[3]     = 0x08
[4]     = chunk length (≤ 0x38)
[5..6]  = device address LE = dword_6d8a2c * profileSlot + chunkOffset
[7]     = 0
[8..]   = payload bytes
```

Loop: `chunkOffset` advances by `0x38` until `dword_6d8a28` (source length).  
Profile slot must be `< 3`. Source buffer is the caller-local copy of the table at `0x6d8a38`.

## Macros / profiles


`sub_42f920` (string `MAIN_PROMPT_DEFAULT`):

1. Confirm dialog
2. For profile slot `i` in `0..2`:
   - build buffer (`sub_42ebb0` / copy from `dword_6d8a38` length `dword_6d8a28`)
   - `sub_441d80(buf, i)` → HID cmd **`0x08`** bulk write
3. Refresh UI (`sub_423ff0`, `sub_42a470`)

UI skins: `Skins\\Macro.ini`, `Composite.ini` (path builder `sub_4158f0`).

## Device IDs

Still: **VID `0x0C45` / PID `0x5004`** (plus `0x320F:0x5000` candidate) from earlier static immediates / OpenRGB.


## Macro apply path (`sub_4381b0`)

Strings: `EXTRA_MACRO_TOO_LONG`, `EXTRA_PROFILE_SPACE_TIGHT`.

Observed sequence when committing macros/profiles:

1. Size checks against `dword_6e639c` (max macro length / space).
2. Build per-slot 0x200-byte working buffers on stack (`slot << 9`).
3. Walk key-table at `0x6d8a38` as **3-byte records** (`dword_6d8a30` count); resolve scancodes via `sub_4023f0` / `sub_402380`.
4. `sub_441780` then **`sub_442040`** (cmd **`0x0A`** bulk — companion table / LED?).
5. For each profile slot `0..2`: **`sub_441d80(buf, slot)`** (cmd **`0x08`**).
6. `sub_441830` finalize.

Default-restore path `sub_42f920` only does step 5 (cmd `0x08` × 3 slots) after confirming `MAIN_PROMPT_DEFAULT`.

## Port mapping

Implemented in `macos/K589Config` → `EVisionProtocol` (+ lighting UI).  
Next: wire `bulkPackets(.writeBulk08, …)` once profile/macro blob layout from `dword_6d8a38` is fully typed.
