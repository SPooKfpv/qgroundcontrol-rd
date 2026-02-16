# CLAUDE.md — QGroundControl Development Guide

## Project Overview

QGroundControl (QGC) is a ground control station for MAVLink-enabled UAVs, supporting PX4 and ArduPilot. It provides flight control, mission planning, and vehicle configuration across Windows, macOS, Linux, Android, and iOS.

## Build System

- **Build tool:** CMake 3.25+ with Ninja (recommended)
- **C++ standard:** C++20
- **Qt version:** Qt 6.10.0
- **Package manager:** CPM (CMake Package Manager)

### Building

```bash
# Install dependencies (Debian/Ubuntu)
sudo ./tools/setup/install-dependencies-debian.sh

# Configure
qt-cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release

# Build
cmake --build build --target all --parallel
```

### Key CMake Options

| Option | Description |
|--------|-------------|
| `-DCMAKE_BUILD_TYPE=Debug\|Release` | Build type (Debug enables tests) |
| `-DQGC_BUILD_TESTING=ON` | Enable unit tests (Debug only) |
| `-DQGC_ENABLE_QMLLINT=ON` | Enable QML linting during build |
| `-DQGC_ENABLE_GST_VIDEOSTREAMING=ON` | GStreamer video backend |
| `-DQGC_VIEWER3D=ON` | 3D Viewer (requires Qt Quick 3D) |

## Testing

```bash
# Build with tests (Debug mode)
cmake --build build --target all --config Debug

# Run all tests
cmake --build build --target check

# Or via ctest
ctest --output-on-failure

# Run specific test
./build/Debug/QGroundControl --unittest:ADSBTest
```

Test source is in `test/` with subdirectories mirroring `src/` structure.

## Linting & Formatting

### Pre-commit hooks

```bash
pre-commit install
pre-commit run --all-files
```

Hooks enforce: trailing whitespace, LF line endings, EOF newlines, YAML/JSON/XML validation, no `Q_ASSERT` in production code, FactMetaData JSON validation, QML lint, Python ruff, shellcheck.

### C++ formatting

Configured in `.clang-format` — Google style with QGC customizations:
- 120 column limit, 4-space indent, no tabs
- Allman braces for functions/classes, K&R for control statements
- Pointers/references left-aligned: `int* ptr`, `const QString& str`

### QML linting

Configured in `.qmllint.ini`. Can be enabled at build time with `-DQGC_ENABLE_QMLLINT=ON`.

## Code Style

Reference files: `CodingStyle.h`, `CodingStyle.cc`, `CodingStyle.qml`

### C++ Conventions

- **Classes:** PascalCase. Prefix with `QGC` only for generic base classes used widely.
- **Methods/variables:** camelCase. Private members prefixed with `_` (e.g., `_privateMethod()`, `_memberVar`).
- **Constants:** `static constexpr` preferred. Use `constexpr` for compile-time constants.
- **Enums:** `enum class` with PascalCase values. Use `Q_ENUM` for QML exposure.
- **Includes:** Group in order: (1) own header, (2) system headers, (3) Qt headers with full paths (`QtCore/QObject`), (4) project headers. Alphabetical within groups, blank lines between groups.
- **Logging:** Use `QGC_LOGGING_CATEGORY(FooLog, "Namespace.Foo")` and `qCDebug`/`qCWarning` — not `qDebug`/`qWarning`.
- **No `Q_ASSERT` in production code.** Use defensive checks with early returns and `qCWarning` logging.
- **Qt6 QML integration:** Use `QML_ELEMENT`, `QML_SINGLETON`, `QML_UNCREATABLE("")`. Use `Q_MOC_INCLUDE` for forward-declared types in `Q_PROPERTY`.
- **Null:** Use `nullptr`, not `NULL`.
- **Override:** Always use `override` keyword for virtual methods.
- **Unused parameters:** Comment out the name, keep the type: `void foo(int /* unused */)`. Do not use `Q_UNUSED` for method parameters.
- **Braces:** Always use braces even for single-line `if`/`for`/`while`.

### QML Conventions

- **Imports:** Unversioned (`import QtQuick`, not `import QtQuick 2.15`). Qt modules first, then QGC modules, separated by blank line.
- **Item order:** (1) id, (2) property bindings (width/height/anchors), (3) public properties, (4) private properties (`_` prefix, use `readonly` where possible), (5) signals, (6) functions, (7) child visual components, (8) Connections, (9) `Component.onCompleted`.
- **No hardcoded sizes.** All sizing relative to `ScreenTools.defaultFontPixelHeight` or `ScreenTools.defaultFontPixelWidth`.
- **No hardcoded colors.** Use `QGCPalette` for all theming.
- **Use QGC controls:** `QGCButton`, `QGCLabel`, `QGCTextField`, `QGCCheckBox`, etc. instead of bare Qt controls.
- **Strings:** Use `qsTr()` for all user-visible strings.
- **Only add `id:` when needed.** Root item uses descriptive id (e.g., `id: root`), not underscore prefix.
- **Vehicle null checks:** Always check `_activeVehicle` before use.

### Property formatting alignment

In QML, align property value assignments using spaces for readability:

```qml
Layout.fillWidth:   true
text:               qsTr("Example")
wrapMode:           Text.WordWrap
```

## Project Structure

```
src/                  # Main source (30+ subsystem directories)
test/                 # Unit tests (mirrors src/ structure)
cmake/                # CMake modules
resources/            # Images, icons, fonts
docs/                 # VitePress documentation
tools/                # Setup and utility scripts
android/              # Android-specific code
deploy/               # Deployment configurations
custom-example/       # Custom build example
translations/         # Localization files (15+ languages)
```

### Key `src/` Subdirectories

- `Vehicle/` — Vehicle management and MAVLink communication
- `MissionManager/` — Mission planning and execution
- `FlightMap/` — Map display and flight visualization
- `QmlControls/` — Reusable QML UI components
- `FactSystem/` — Parameter and settings metadata system
- `Comms/` — Communication links (serial, UDP, TCP)
- `Camera/` — Camera management
- `ADSB/` — ADS-B traffic awareness
- `Terrain/` — Terrain data queries
- `GPS/` — GPS/RTK support

## Git Workflow

- Main branch: `master`
- Feature branches for development
- Pre-commit hooks run automatically on commit
