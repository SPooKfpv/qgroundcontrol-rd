# Rift QGC — Changes from Upstream QGroundControl

## 1. Pre-Flight Setup System

**Startup dialog** shown every launch (after splash screen) with:
- **Vehicle selection** — combobox populated from `config/vehicles/*.json` files. Each vehicle JSON has a `serialNum` field (integer) that uniquely identifies the drone type (e.g. `"serialNum": 1` for Wåsp 1.7). The `selectedVehicle` setting stores which config is active.
- **Failsafe mode** — Rally Point / RTL Home / Land, stored locally, applied to vehicle via MAVLink params (`FS_THR_ENABLE`, `RALLY_ENABLE`) when vehicle connects. Rally point shows reminder to set manually.
- **Loiter time** — configurable seconds (0–300, default 30) the vehicle loiters at RTL destination before landing. Applied to ArduPilot `RTL_LOIT_TIME` param for Rally Point and RTL Home modes.
- **UDP port** — configurable connection port, applied to auto-connect listener on startup
- **Checklist toggle** — combobox populated from `config/checklists/*.json`, JSON format with groups and manual tick-off items

**Key files:** `PreFlightSetupSettings.h/.cc`, `PreFlightSetup.SettingsGroup.json`, `PreFlightSetupApplier.h/.cc`, `PreFlightSetupDialog.qml`

## 2. Splash Screen & Startup Sequence

- Window starts hidden (`visible: false`) — no flash before splash
- `MainWindowSavedState` defers visibility restore to `applyPendingVisibility()`
- Splash renders before blocking `app.init()` via `processEvents()`
- C++ calls `showWindow()` after splash finishes

**Files:** `main.cc`, `MainWindow.qml`, `MainWindowSavedState.qml`

## 3. Windows 11 Title Bar Branding

- DWM API sets title bar and border color to `#23291a` (dark green) via `DwmSetWindowAttribute` with `DWMWA_CAPTION_COLOR` / `DWMWA_BORDER_COLOR`

**Files:** `main.cc`, `CMakeLists.txt` (linked `dwmapi`)

## 4. Toolbar Customizations

- **Fixed background color** — toolbar stays `#23291a` regardless of vehicle status
- **Status dot indicator** — colored dot next to status text replaces background color changes (green/yellow/red based on vehicle state)
- **Display Joystick button** — toggles on-screen virtual joystick
- **USB Joystick button** — popup with controller combobox, calibration gate (enable disabled until calibrated), navigate to Joystick config page. Color: green (enabled), orange (uncalibrated), red (disabled)

**Files:** `FlyViewToolBar.qml`, `MainStatusIndicator.qml`, `MainWindow.qml`, `SetupView.qml`

## 5. Toolstrip Menu Additions (Left Side)

- **Auto** button — submenu: Start Mission, Continue Mission, Clear Mission, Patterns (Figure 8, Orbit, Survey placeholders). Patterns require a reference point to be set.
- **Terminal Guidance** button — two-line text, submenu: Cruise, Strike Static, Strike Moving (placeholders)
- **Failsafe** button — change failsafe mode in-flight (Rally Point / RTL Home / Land), configurable loiter time before landing, applies immediately to connected ArduPilot vehicle via MAVLink params (`FS_THR_ENABLE`, `RALLY_ENABLE`, `RTL_LOIT_TIME`). Also shows rally point count and Clear Rally Points button.
- Removed auto-popup of "Start Mission" when drone has mission loaded

**Files:** `AutoMissionButton.qml`, `AutoMissionPanel.qml`, `TerminalGuidanceButton.qml`, `TerminalGuidancePanel.qml`, `FailsafeButton.qml`, `FailsafePanel.qml`, `FlyViewToolStripActionList.qml`, `GuidedActionsController.qml`

## 6. Map Click Menu Additions

- **Set Rally Point** — adds rally point at clicked location and syncs to vehicle (`syncToVehicle()` Q_INVOKABLE wrapper added to `RallyPointController.h`)
- **Set Pattern Reference Point** — stores coordinate in `globals.patternReferencePoint`, shows "P" marker on map, used by Auto Mission pattern buttons

**Files:** `FlyViewMap.qml`, `RallyPointController.h`, `MainWindow.qml`

## 7. Right Panel — Video / HUD / Console

- **GStreamer video** (top) — locked 16:9 aspect ratio, uses `FlightDisplayViewVideo`
- **HUD header** — shows drone ID (`BRD_SERIAL_NUM`), vehicle name (from pre-flight config), fleet ID (`SYSID_THISMAV`), UDP port
- **HUD instruments** (middle) — attitude indicator, compass, numeric telemetry (ALT, SPD, HDG, DIST, BAT)
- **MAVLink console** (bottom) — green-on-black terminal (12pt Courier) showing all vehicle messages, auto-scroll, Clear button
- **Resizable** via drag handle on left edge (min 25%, max 60% of screen width)
- Panel sits below toolbar (not hidden under it)
- Map area fills remaining space to the left

**Files:** `FlyViewRightPanel.qml`, `FlyView.qml`, `CMakeLists.txt`

## 8. Removed / Changed Features

- Terrain Load Progress (top right) — removed
- Auto-popup for Start/Continue Mission — removed
- **Vehicle setup incomplete auto-navigate** — replaced with a warning dialog ("Yes" = Go to Setup, "No" = dismiss). No longer forces the user into the config view.

**Files:** `AutoPilotPlugin.cc`, `MainWindow.qml`

## Drone Type Identification

Each drone configuration in `config/vehicles/*.json` is identified by the **`serialNum`** integer field. Example: `"serialNum": 1` for the Wåsp 1.7. The `selectedVehicle` setting (stored in `PreFlightSetupSettings`) references the JSON filename, and the vehicle's properties (name, type, firmware, specs, default checklist, default UDP port) are loaded from that file.
