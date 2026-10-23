# VitalsMac

A native macOS menu-bar system monitor. A live summary sits in your menu bar, and a dashboard shows
the details and history.

```
CPU 32% · 80°C · 3625 rpm
```

Everything runs locally. VitalsMac makes no network connections and sends nothing anywhere.

## Features

- **Menu bar:** CPU usage, hottest CPU temperature and fan speed, refreshed every 2 seconds. Choose
  which parts to show in Settings.
- **Dropdown:** processor, temperatures, fans, memory, storage, network, battery and system readings.
  Unnamed temperature sensors are grouped under "All sensors".
- **Dashboard** (menu → *Open Dashboard*, or launch the app again):
  - **Overview:** health score, storage, memory, processor (user/system split), GPU and network with
    live charts.
  - **Performance:** usage for each CPU core, load averages, thermal state and uptime, and the top
    processes by CPU or memory (sampled only while this page is open).
  - **Sensors:** every reading.
  - **History:** CPU, GPU, temperature, fan, memory and network over 1 hour, 24 hours or 7 days.
    One averaged point per minute is saved to
    `~/Library/Application Support/VitalsMac/history.jsonl` and kept for 7 days.
- **Thermal alert:** a notification when the CPU stays hot (default 90°C for 30 seconds), with a
  cool-down so it does not repeat. Thresholds are adjustable.
- **Launch at login** from Settings.

## Requirements

- macOS 15 or later
- Swift 6 toolchain (Xcode 16 or later) to build

Developed and tested on an Intel Mac. Temperatures and fan speeds come from the System Management
Controller (SMC). Apple Silicon Macs expose different SMC keys, so some sensors may be missing there;
that has not been tested.

## Build and run

```bash
swift build            # debug build
swift test             # unit tests (includes live checks against this machine's sensors)
scripts/build-app.sh   # builds VitalsMac.app into ~/Library/Caches/VitalsMac/build (release, ad-hoc signed)
scripts/build-app.sh --install   # also copies it to ~/Applications
```

The app is ad-hoc signed, which is fine on the Mac that built it. Running it on another Mac needs a
proper Developer ID signature, or you can build it there yourself.

## Layout

| Path | What it holds |
|---|---|
| `Sources/CSMC` | Small C bridge for the SMC kernel interface |
| `Sources/SensorKit` | Sensor reading, math, health score, history storage (no UI, fully tested) |
| `Sources/VitalsMac` | SwiftUI menu-bar app, dashboard and settings |
| `Tests/SensorKitTests` | Unit tests |

## License

MIT. See [LICENSE](LICENSE).

VitalsMac is an independent project written from scratch. It is not affiliated with any other app or
extension named Vitals.
