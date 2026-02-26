# Pre-Flight Setup Dialog Implementation Plan

Created: 2026-02-26
Status: VERIFIED
Approved: Yes
Iterations: 0
Worktree: No
Type: Feature

> **Status Lifecycle:** PENDING -> COMPLETE -> VERIFIED
> **Iterations:** Tracks implement->verify cycles (incremented by verify phase)

## Summary

**Goal:** Show a mandatory pre-flight setup dialog every startup (after splash, before main window interaction) that lets the user select a failsafe mode (Rally Point / RTL Home / Loiter Hold), toggle and select a checklist from JSON files scanned from `config/checklists/`, and confirm to proceed. Failsafe selection is stored locally and applied to the vehicle via ArduPilot MAVLink parameters when a vehicle connects. Rally Point selection shows a reminder to set the rally point manually.

**Architecture:** QML-based dialog using the existing `QGCPopupDialog` pattern, shown in `MainWindow.qml` after first-run prompts complete (replacing the `showPreFlightChecklistIfNeeded` call). A new `PreFlightSetupSettings` C++ settings group stores failsafe mode, checklist enabled, and selected checklist name using QGC's Fact/Settings system. A C++ `ChecklistFileManager` scans `config/checklists/*.json` and exposes the list to QML. When a vehicle connects and parameters are ready, a C++ handler applies the stored failsafe setting to ArduPilot parameters.

**Tech Stack:** C++20, Qt 6.10.0 QML, QGC Fact/Settings system, MAVLink parameter writing via ParameterManager

## Scope

### In Scope

- New `PreFlightSetupDialog.qml` — modal QML dialog with failsafe radio buttons, checklist toggle/combobox, confirm button
- New `PreFlightSetupSettings` C++ settings group — persists failsafe mode, checklist enabled flag, selected checklist name
- New `ChecklistFileManager` C++ class — scans `config/checklists/` folder, exposes list of available checklists to QML
- Example checklist JSON file(s) in `config/checklists/`
- CMake changes to copy `config/checklists/` to build output
- ArduPilot failsafe parameter application on vehicle connect
- Rally Point reminder message when Rally Point failsafe is selected
- Integration into MainWindow.qml startup flow (after first-run prompts)

### Out of Scope

- PX4 failsafe parameter support (ArduPilot only, per user request)
- Auto sensor checks in checklists (manual tick-off only for now)
- Editing checklists from within the app (JSON files edited externally)
- Checklist tick-off display in this dialog — the dialog is for *selecting* which checklist to use and enabling/disabling it. Actual tick-off of checklist items happens in the existing fly view checklist panel (PreFlightCheckList.qml). The JSON files define the checklist structure (groups + items) for future use by an enhanced checklist viewer; for now the dialog only selects which checklist file is active.

## Prerequisites

- QGC builds and runs successfully (confirmed by user)
- Splash screen feature already integrated in `main.cc`
- `config/` directory pattern already established for `theme.json`

## Context for Implementer

- **Patterns to follow:**
  - Settings group: Follow `src/Settings/AppSettings.h/.cc` and `App.SettingsGroup.json` for the Fact/Settings pattern. Each setting is defined with `DEFINE_SETTINGFACT` macro in the header, `DECLARE_SETTINGSFACT` in the .cc, and metadata in a `.SettingsGroup.json` file.
  - Dialog: Follow `src/QmlControls/QGCPopupDialog.qml` for dialog structure. Use `QGCRadioButton`, `QGCCheckBox`, `QGCComboBox`, `QGCButton`, `QGCLabel` from `QGroundControl.Controls`.
  - File scanning: Follow `src/QmlControls/ThemeLoader.cc` for the pattern of scanning files from `config/` next to the executable.
  - Parameter setting: **Always** call `vehicle->parameterManager()->parameterExists(componentId, paramName)` first. Only if it returns `true`, call `getParameter(componentId, paramName)->setRawValue(value)`. Note: `getParameter()` does NOT have a `reportMissing` parameter — calling it on a missing param triggers `reportMissingParameter()` which shows an error dialog. Use component ID `-1` (`ParameterManager::defaultComponentId`) for default component.
  - Vehicle connection signal: Listen to `MultiVehicleManager::parameterReadyVehicleAvailableChanged(true)` to know when a vehicle has connected and parameters are ready.

- **Conventions:**
  - Private members prefixed with `_`
  - QML files use `QGC` prefix for custom controls
  - Settings JSON files named `<GroupName>.SettingsGroup.json`
  - Logging categories declared with `QGC_LOGGING_CATEGORY`

- **Key files:**
  - `src/Settings/SettingsGroup.h` — Macros: `DEFINE_SETTING_NAME_GROUP`, `DECLARE_SETTINGGROUP`, `DECLARE_SETTINGSFACT`, `DEFINE_SETTINGFACT`
  - `src/Settings/SettingsManager.h/.cc` — Registers all settings groups, provides singleton access
  - `src/UI/MainWindow.qml:32-67` — First-run prompt flow that triggers `showPreFlightChecklistIfNeeded` when complete
  - `src/QmlControls/QGCPopupDialog.qml` — Base dialog component (Popup-based, modal, has title/buttons)
  - `src/Vehicle/MultiVehicleManager.h:64` — `parameterReadyVehicleAvailableChanged` signal
  - `src/QmlControls/CMakeLists.txt` — Where QML files are registered in the `QGroundControl.Controls` module

- **Gotchas:**
  - QML files from various directories are added to `src/QmlControls/CMakeLists.txt` due to Windows build limitations (see comment at line 180)
  - Settings JSON files are embedded as Qt resources via `qt_add_resources` with `/json` prefix
  - `QGCPopupDialog` auto-destroys on close by default (`destroyOnClose: true`)
  - Vehicle parameter access requires `parametersReady` to be true — always check before calling `getParameter()`

- **Domain context:**
  - ArduPilot Copter failsafe actions: `FS_THR_ENABLE` controls throttle failsafe behavior. Values: 0=Disabled, 1=RTL, 2=Continue, 3=Land, 4=SmartRTL_or_RTL, 5=SmartRTL_or_Land
  - **Corrected mapping:** SmartRTL traces flight path home and does NOT use rally points. Standard RTL (value 1) DOES use rally points when `RALLY_ENABLE=1` is set.
  - For our dialog: "RTL Home" maps to FS_THR_ENABLE=1 (RTL without rally), "Loiter Hold" maps to FS_THR_ENABLE=2 (Continue/Loiter in place), "Rally Point" maps to FS_THR_ENABLE=1 (RTL) **plus** setting `RALLY_ENABLE=1` so RTL uses rally points
  - We only set `FS_THR_ENABLE` — NOT `FS_GCS_ENABLE` (user did not request GCS failsafe, and value semantics differ between vehicle types)
  - Rally points are uploaded as mission items (MAV_CMD_NAV_RALLY_POINT), not parameters — hence the reminder to set them manually
  - **Important:** Always call `parameterExists()` before `getParameter()` — the latter has no `reportMissing` parameter and will show error dialogs for missing params

## Runtime Environment

- **Build command:** `cmake --build build/Desktop_Qt_6_10_0_MSVC2022_64bit-Debug/ --target QGroundControl` (or via Qt Creator Build)
- **Launch:** Run the `QGroundControl` executable from the build output directory
- **Expected startup sequence:** Splash screen (3s fade) -> First-run prompts (if any) -> Pre-flight setup dialog (modal overlay) -> User clicks Confirm -> Main window becomes interactive
- **Verify settings persistence:** Close app, relaunch, verify dialog shows previously selected values
- **Verify failsafe application:** After confirming dialog, use Comms > Add New Connection > MockLink (ArduPilot) to connect a simulated vehicle; check that failsafe parameters are set (visible in Vehicle Setup > Parameters)

## Progress Tracking

**MANDATORY: Update this checklist as tasks complete. Change `[ ]` to `[x]`.**

- [x] Task 1: PreFlightSetupSettings C++ settings group
- [x] Task 2: ChecklistFileManager C++ class
- [x] Task 3: PreFlightSetupDialog QML dialog
- [x] Task 4: MainWindow integration and startup flow
- [x] Task 5: Failsafe parameter application on vehicle connect
- [x] Task 6: Example checklist JSON files and CMake config copy
- [x] Task 7: Build verification and integration testing

**Total Tasks:** 7 | **Completed:** 7 | **Remaining:** 0

## Implementation Tasks

### Task 1: PreFlightSetupSettings C++ Settings Group

**Objective:** Create a new settings group that persists the user's failsafe mode selection, checklist enabled state, and selected checklist name using QGC's Fact/Settings system.

**Dependencies:** None

**Files:**

- Create: `src/Settings/PreFlightSetupSettings.h`
- Create: `src/Settings/PreFlightSetupSettings.cc`
- Create: `src/Settings/PreFlightSetup.SettingsGroup.json`
- Modify: `src/Settings/SettingsManager.h` — Add forward declaration, Q_PROPERTY, accessor, member
- Modify: `src/Settings/SettingsManager.cc` — Instantiate and register PreFlightSetupSettings
- Modify: `src/Settings/CMakeLists.txt` — Add new source files

**Key Decisions / Notes:**

- Follow the exact pattern of `AppSettings.h/.cc` and `App.SettingsGroup.json`
- Three facts: `failsafeMode` (uint32, enum: "Rally Point,RTL Home,Loiter Hold" with values 0,1,2, default 1), `checklistEnabled` (bool, default false), `selectedChecklist` (string, default "")
- The `failsafeMode` enum values are internal IDs — mapping to actual ArduPilot parameter values happens in Task 5
- Use `DEFINE_SETTING_NAME_GROUP()`, `DECLARE_SETTINGGROUP(PreFlightSetup, "PreFlightSetup")`, `DECLARE_SETTINGSFACT` macros
- **CRITICAL:** The `name` arg in `DECLARE_SETTINGGROUP` ("PreFlightSetup") MUST exactly match the JSON filename prefix (`PreFlightSetup.SettingsGroup.json`). A mismatch causes `exit(-1)` at startup.
- **No manual qt_add_resources needed** — `src/Settings/CMakeLists.txt` auto-detects JSON files via `file(GLOB_RECURSE)`. Do NOT add a manual resource entry or the JSON will be double-registered.
- Register in SettingsManager following the pattern of other settings groups (forward declare, Q_PROPERTY, Q_MOC_INCLUDE, accessor, private member, instantiate in constructor)

**Definition of Done:**

- [ ] `PreFlightSetupSettings` class compiles with no errors
- [ ] Settings group registered in `SettingsManager` and accessible via `settingsManager->preFlightSetupSettings()`
- [ ] JSON metadata defines all three facts with correct types, enums, and defaults
- [ ] Settings values accessible via Q_PROPERTY from QML (verified in Task 7 runtime test)

**Verify:**

- Build compiles without errors: `cmake --build build/ --target QGroundControl`

### Task 2: ChecklistFileManager C++ Class

**Objective:** Create a C++ class that scans the `config/checklists/` directory for JSON files and exposes the list of available checklist names to QML.

**Dependencies:** None

**Files:**

- Create: `src/QmlControls/ChecklistFileManager.h`
- Create: `src/QmlControls/ChecklistFileManager.cc`
- Modify: `src/QmlControls/CMakeLists.txt` — Add new source files to `target_sources`

**Key Decisions / Notes:**

- Singleton pattern with `QML_ELEMENT` and `QML_SINGLETON` (or use static methods exposed via `QGroundControlQmlGlobal`)
- Simpler approach: Make it a `QObject` with `QML_ELEMENT`, instantiated by the dialog QML
- Scans `<appDir>/config/checklists/` for `*.json` files (same search path pattern as `ThemeLoader.cc`)
- Exposes `Q_PROPERTY(QStringList availableChecklists READ availableChecklists NOTIFY availableChecklistsChanged)` — returns list of checklist names (filename without .json extension)
- Exposes `Q_INVOKABLE QJsonObject loadChecklist(const QString &name)` to load a specific checklist's JSON content
- Uses `QGC_LOGGING_CATEGORY` for logging
- The scan happens on construction and can be refreshed via `Q_INVOKABLE void refresh()`

**Definition of Done:**

- [ ] Class compiles with `QML_ELEMENT` macro; instantiable in QML via `ChecklistFileManager {}`
- [ ] `availableChecklists` property returns names of .json files from config/checklists/
- [ ] `loadChecklist()` returns parsed JSON content for a given checklist name
- [ ] Returns empty list gracefully when directory doesn't exist or contains no .json files

**Verify:**

- Build compiles without errors

### Task 3: PreFlightSetupDialog QML Dialog

**Objective:** Create the QML dialog UI with failsafe radio buttons, checklist toggle with combobox, rally point reminder, and confirm button.

**Dependencies:** Task 1, Task 2

**Files:**

- Create: `src/QmlControls/PreFlightSetupDialog.qml`
- Modify: `src/QmlControls/CMakeLists.txt` — Add QML file to `qt_add_qml_module` QML_FILES list

**Key Decisions / Notes:**

- Extends `QGCPopupDialog` with `buttons: Dialog.Ok` (uses standard accept button as "Confirm" — follows established codebase pattern, avoids layout issues with hidden buttons)
- Failsafe section shows a note "(ArduPilot vehicles only)" to avoid confusion on PX4 builds
- Title: "Pre-Flight Setup"
- Layout: `ColumnLayout` with three sections:
  1. **Failsafe Mode** section with `QGCLabel` header and three `QGCRadioButton`s in a `ButtonGroup`. Selecting "Rally Point" shows a warning label: "Remember to set your rally point before flight"
  2. **Checklist** section with `QGCCheckBox` "Enable pre-flight checklist" and `QGCComboBox` (enabled only when checkbox is checked) populated from `ChecklistFileManager.availableChecklists`
  3. **Confirm** `QGCButton` (primary) labeled "Confirm" that saves settings and closes dialog
- Reads/writes settings via `QGroundControl.settingsManager.preFlightSetupSettings`
- Dialog uses `closePolicy: Popup.NoAutoClose` to prevent closing without confirming
- `destroyOnClose: true` (default)
- On confirm: update all setting facts with current selections, then close

**Definition of Done:**

- [ ] Dialog shows failsafe mode radio buttons (Rally Point, RTL Home, Loiter Hold)
- [ ] Rally Point selection displays reminder text
- [ ] Checklist checkbox toggles combobox enabled state
- [ ] Combobox populated from ChecklistFileManager
- [ ] Confirm button saves all selections to settings and closes dialog
- [ ] Dialog cannot be closed without clicking Confirm (no X button, no escape)

**Verify:**

- Build compiles without errors
- QML file lints clean

### Task 4: MainWindow Integration and Startup Flow

**Objective:** Wire the `PreFlightSetupDialog` into the MainWindow startup sequence so it shows after first-run prompts complete, before the main window becomes interactive.

**Dependencies:** Task 3

**Files:**

- Modify: `src/UI/MainWindow.qml` — Replace `showPreFlightChecklistIfNeeded` call with pre-flight setup dialog display

**Key Decisions / Notes:**

- In `MainWindow.qml`, the `firstRunPromptManager.nextPrompt()` function at line 64 calls `showPreFlightChecklistIfNeeded()` when all first-run prompts are done
- Replace that call with showing the `PreFlightSetupDialog`
- Use `Component` + `createObject(mainWindow)` + `.open()` pattern (same as first-run prompts)
- After the setup dialog is accepted/closed, then call the original `showPreFlightChecklistIfNeeded()` signal
- The dialog shows every startup (no "already shown" tracking like first-run prompts)
- The splash screen hides the main window; by the time first-run prompts run, the main window is visible. The dialog will appear as a modal overlay.

**Definition of Done:**

- [ ] Pre-flight setup dialog appears after splash and first-run prompts on every startup
- [ ] Main window is visible but blocked by the modal dialog
- [ ] After confirming, `showPreFlightChecklistIfNeeded` signal is emitted so the existing fly-view checklist panel can appear if `useChecklist` is enabled (the new dialog configures settings, the existing system uses them)
- [ ] Dialog appears on every launch (not just first run)

**Verify:**

- Build compiles and app launches showing the dialog

### Task 5: Failsafe Parameter Application on Vehicle Connect

**Objective:** When a vehicle connects and its parameters are ready, read the stored failsafe setting and apply it to the vehicle's ArduPilot parameters via MAVLink.

**Dependencies:** Task 1

**Files:**

- Create: `src/Vehicle/PreFlightSetupApplier.h`
- Create: `src/Vehicle/PreFlightSetupApplier.cc`
- Modify: `src/Vehicle/CMakeLists.txt` — Add new source files
- Modify: `src/QGCApplication.cc` — Instantiate PreFlightSetupApplier during init

**Key Decisions / Notes:**

- New class `PreFlightSetupApplier` connects to `MultiVehicleManager::parameterReadyVehicleAvailableChanged`
- When signal fires with `true`, get the active vehicle and check if it's ArduPilot (`vehicle->apmFirmware()`)
- **Only apply on first connect per session** — track vehicle IDs already configured in a `QSet<int> _appliedVehicleIds`. Skip if vehicle ID already in set. This prevents overwriting manual parameter changes on reconnect.
- Map failsafe mode to ArduPilot `FS_THR_ENABLE` parameter only (NOT `FS_GCS_ENABLE` — value semantics differ between vehicle types):
  - "RTL Home" (mode 1) → Set `FS_THR_ENABLE` to 1 (RTL)
  - "Loiter Hold" (mode 2) → Set `FS_THR_ENABLE` to 2 (Continue/Loiter in place)
  - "Rally Point" (mode 0) → Set `FS_THR_ENABLE` to 1 (RTL) AND set `RALLY_ENABLE` to 1 (so RTL uses rally points)
- **MUST call `parameterManager()->parameterExists(-1, paramName)` before `getParameter()`** — `getParameter()` has NO `reportMissing` parameter and will show error dialogs for missing params
- If the parameter doesn't exist on this vehicle type, log a warning and skip
- If Rally Point mode is selected, show a message via `qgcApp()->showAppMessage()` reminding user to set rally points

**Definition of Done:**

- [ ] When ArduPilot vehicle connects (first connect only per vehicle ID), stored failsafe mode is applied to `FS_THR_ENABLE`
- [ ] Rally Point mode additionally sets `RALLY_ENABLE=1` if parameter exists
- [ ] Non-ArduPilot vehicles are skipped with a log message
- [ ] Missing parameters checked via `parameterExists()` before `getParameter()` — no error dialogs for missing params
- [ ] Reconnects of same vehicle ID do not re-apply (prevents overwriting manual changes)
- [ ] When Rally Point mode is active and a vehicle connects, `showAppMessage()` displays a reminder to set rally points before flight

**Verify:**

- Build compiles without errors

### Task 6: Example Checklist JSON Files and CMake Config Copy

**Objective:** Create example checklist JSON files in `config/checklists/` and update CMake to copy the directory to the build output.

**Dependencies:** None

**Files:**

- Create: `config/checklists/multirotor.json`
- Create: `config/checklists/fixed-wing.json`
- Modify: `CMakeLists.txt` — Add POST_BUILD step to copy `config/checklists/` directory

**Key Decisions / Notes:**

- JSON format for checklists:
  ```json
  {
    "name": "Multirotor Pre-Flight",
    "version": 1,
    "groups": [
      {
        "name": "Initial Checks",
        "items": [
          { "text": "Props mounted and secured?", "type": "manual" },
          { "text": "Battery charged and secured?", "type": "manual" },
          { "text": "GPS antenna clear?", "type": "manual" }
        ]
      },
      {
        "name": "Before Takeoff",
        "items": [
          { "text": "Flight area clear of obstacles and people?", "type": "manual" },
          { "text": "Wind conditions acceptable?", "type": "manual" },
          { "text": "Mission loaded and verified?", "type": "manual" }
        ]
      }
    ]
  }
  ```
- `type` field is always "manual" for now; reserved for future "auto" sensor checks
- CMake copies entire `config/checklists/` directory using `cmake -E copy_directory` (NOT `copy_if_different` which is for single files). This ensures user-added JSON files are automatically copied without CMake edits.
- The `name` field in JSON is the display name; the filename (without .json) is the identifier

**Definition of Done:**

- [ ] `config/checklists/multirotor.json` exists with valid JSON structure
- [ ] `config/checklists/fixed-wing.json` exists with valid JSON structure
- [ ] CMake copies checklists to build output directory `config/checklists/`
- [ ] ChecklistFileManager can discover and load these files

**Verify:**

- Build copies checklists to output directory
- JSON files parse without error

### Task 7: Build Verification and Integration Testing

**Objective:** Verify the complete feature works end-to-end: app launches, dialog appears, settings persist, and failsafe applies on vehicle connect.

**Dependencies:** Task 1, Task 2, Task 3, Task 4, Task 5, Task 6

**Files:**

- No new files — testing existing implementation

**Key Decisions / Notes:**

- Manual verification since QGC doesn't have a QML test framework for dialogs
- Check: App starts → splash → dialog appears → can select failsafe mode → can toggle checklist → combobox shows JSON files → confirm closes dialog → settings persist on restart
- Check: If Rally Point selected, reminder text appears in dialog
- Check: Build has no warnings related to new code
- Check: All new source files compile cleanly

**Definition of Done:**

- [ ] Full build compiles with no errors in new code
- [ ] App launches and shows pre-flight setup dialog after splash
- [ ] All dialog controls function correctly
- [ ] Settings persist across app restart
- [ ] No new compiler warnings

**Verify:**

- `cmake --build build/` completes with 0 errors
- App launches successfully

## Testing Strategy

- **Unit tests:** QGC's test framework (QTest + MockLink) doesn't easily test QML dialogs. Focus on testing `ChecklistFileManager` JSON parsing and `PreFlightSetupApplier` parameter mapping logic if test infrastructure permits.
- **Integration tests:** Verify settings persistence by checking QSettings values after dialog interactions.
- **Manual verification:** Launch app, interact with dialog, verify persistence, verify parameter application with MockLink vehicle.

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Vehicle parameters not available when applying failsafe | Low | Med | Only apply when `parameterReadyVehicleAvailableChanged(true)` fires; check parameter exists before setting |
| `config/checklists/` directory doesn't exist on user's system | Med | Low | `ChecklistFileManager` returns empty list gracefully; combobox shows "No checklists found" |
| QML dialog blocks app startup if something breaks | Low | High | Guard `Component.createObject()` with null check — if it returns null, log error via `console.error()` and call `showPreFlightChecklistIfNeeded()` directly so the main window becomes interactive. Add `Component.onStatusChanged` handler to log QML loading errors. |
| ArduPilot parameter names vary between vehicle types (Copter vs Rover vs Plane) | Med | Med | Call `parameterExists(-1, name)` before `getParameter()`; log and skip if parameter not found |
| User changes failsafe setting but forgets to set rally point | Med | Med | Show reminder text in dialog when Rally Point is selected; show app message when vehicle connects with Rally Point mode |

## Goal Verification

### Truths (what must be TRUE for the goal to be achieved)

- Pre-flight setup dialog appears on every app startup after the splash screen
- User can select one of three failsafe modes (Rally Point, RTL Home, Loiter Hold)
- User can enable/disable checklist and select from available checklists
- Failsafe and checklist selections persist across restarts
- When a vehicle connects, the stored failsafe mode is applied to ArduPilot parameters
- Rally Point selection shows a reminder to set rally points manually
- Checklists are loaded from JSON files in `config/checklists/`

### Artifacts (what must EXIST to support those truths)

- `src/Settings/PreFlightSetupSettings.h/.cc` — stores failsafe mode, checklist enabled, selected checklist
- `src/Settings/PreFlightSetup.SettingsGroup.json` — fact metadata for settings
- `src/QmlControls/ChecklistFileManager.h/.cc` — scans and loads checklist JSON files
- `src/QmlControls/PreFlightSetupDialog.qml` — the dialog UI with all controls
- `src/Vehicle/PreFlightSetupApplier.h/.cc` — applies failsafe to vehicle on connect
- `config/checklists/multirotor.json` — example checklist file
- `config/checklists/fixed-wing.json` — example checklist file

### Key Links (critical connections that must be WIRED)

- `MainWindow.qml` firstRunPromptManager.nextPrompt() → opens `PreFlightSetupDialog`
- `PreFlightSetupDialog` Confirm button → writes to `PreFlightSetupSettings` facts
- `ChecklistFileManager` → scans filesystem → populates combobox in dialog
- `PreFlightSetupApplier` → listens to `parameterReadyVehicleAvailableChanged` → reads `PreFlightSetupSettings` → sets vehicle parameters
- `SettingsManager` → instantiates and exposes `PreFlightSetupSettings` to QML

## Open Questions

- None — requirements are clear from user discussion.

### Deferred Ideas

- PX4 failsafe parameter support
- Auto sensor checks in checklist items (type: "auto")
- In-app checklist editor
- Ability to skip the dialog (checkbox "Don't show on startup")
