/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

/// Pre-Flight Setup Dialog shown every startup (after splash screen) before the main window
/// becomes interactive. Lets the user select vehicle, failsafe mode, UDP port and checklist.
/// Monitors for connected drones via BRD_SERIAL_NUM and auto-selects matching vehicle/checklist.
QGCPopupDialog {
    id:      root
    title:   qsTr("Pre-Flight Setup")
    buttons: Dialog.Ok

    property int    _selectedFailsafeMode: QGroundControl.settingsManager.preFlightSetupSettings.failsafeMode.rawValue
    property bool   _udpEditMode:          false
    property string _detectedVehicle:      ""   // config name from BRD_SERIAL_NUM match
    property bool   _autoDetected:         false // true when vehicle was auto-detected

    // --- Connection monitoring ---
    // Bind to parameterReadyVehicleAvailable so we re-check when a vehicle's params become ready
    property bool _paramReady: QGroundControl.multiVehicleManager.parameterReadyVehicleAvailable

    onAccepted: {
        const settings = QGroundControl.settingsManager.preFlightSetupSettings
        settings.failsafeMode.rawValue = _selectedFailsafeMode

        // Save loiter time
        const loiterVal = parseInt(loiterTimeField.text)
        if (!isNaN(loiterVal) && loiterVal >= 0 && loiterVal <= 300) {
            settings.loiterTime.rawValue = loiterVal
        }

        // Save vehicle selection
        if (vehicleConfigManager.availableVehicles.length > 0 && vehicleComboBox.currentIndex >= 0) {
            settings.selectedVehicle.rawValue = vehicleConfigManager.availableVehicles[vehicleComboBox.currentIndex]
        }

        // Save UDP port
        const portVal = parseInt(udpPortField.text)
        if (!isNaN(portVal) && portVal > 0 && portVal <= 65535) {
            settings.udpPort.rawValue = portVal
        }

        // Save checklist settings
        settings.checklistEnabled.rawValue = checklistCheckBox.checked
        if (checklistCheckBox.checked && checklistFileManager.availableChecklists.length > 0 && checklistComboBox.currentIndex >= 0) {
            settings.selectedChecklist.rawValue = checklistFileManager.availableChecklists[checklistComboBox.currentIndex]
        }
    }

    on_ParamReadyChanged: _tryDetectVehicle()

    // Non-visual helpers
    ChecklistFileManager  { id: checklistFileManager }
    VehicleConfigManager  { id: vehicleConfigManager }

    // Timer to recheck after UDP port change (gives LinkManager time to reconnect)
    Timer {
        id:       recheckTimer
        interval: 3000
        repeat:   true
        onTriggered: {
            _tryDetectVehicle()
            // Stop after successful detection or after ~15s (5 attempts)
            if (root._autoDetected || _recheckCount >= 5) {
                stop()
                _recheckCount = 0
            }
            _recheckCount++
        }
        property int _recheckCount: 0
    }

    // Dialog content — MUST be last visual child so QGCPopupDialog re-parents it correctly
    ColumnLayout {
        id:      contentLayout
        width:   Math.min(mainWindow.width - ScreenTools.defaultFontPixelWidth * 8,
                          ScreenTools.defaultFontPixelWidth * 50)
        spacing: ScreenTools.defaultFontPixelHeight

        QGCPalette { id: qgcPal; colorGroupEnabled: true }

        // ── Vehicle Selection ───────────────────────────────────────────────

        QGCLabel {
            text:           qsTr("Vehicle")
            font.pointSize: ScreenTools.mediumFontPointSize
            font.bold:      true
        }

        // Connection status label
        QGCLabel {
            id:               connectionStatusLabel
            visible:          root._detectedVehicle.length > 0 || QGroundControl.multiVehicleManager.activeVehicleAvailable
            text: {
                if (root._detectedVehicle.length > 0) {
                    return qsTr("Connected \"%1\"").arg(vehicleConfigManager.displayName(root._detectedVehicle))
                } else if (QGroundControl.multiVehicleManager.activeVehicleAvailable) {
                    return qsTr("Connected — unknown vehicle (no BRD_SERIAL_NUM match)")
                }
                return ""
            }
            color:            root._detectedVehicle.length > 0 ? qgcPal.colorGreen : qgcPal.colorOrange
            wrapMode:         Text.WordWrap
            Layout.fillWidth: true
        }

        QGCComboBox {
            id:               vehicleComboBox
            Layout.fillWidth: true
            enabled:          vehicleConfigManager.availableVehicles.length > 0
            model: {
                if (vehicleConfigManager.availableVehicles.length === 0)
                    return [qsTr("No vehicles found")]
                var names = []
                for (var i = 0; i < vehicleConfigManager.availableVehicles.length; i++)
                    names.push(vehicleConfigManager.displayName(vehicleConfigManager.availableVehicles[i]))
                return names
            }

            Component.onCompleted: {
                const savedName = QGroundControl.settingsManager.preFlightSetupSettings.selectedVehicle.rawValue
                const idx = vehicleConfigManager.availableVehicles.indexOf(savedName)
                currentIndex = (idx >= 0) ? idx : 0
                _applyVehicleDefaults()
                // Try detecting connected vehicle at startup
                _tryDetectVehicle()
            }

            onCurrentIndexChanged: _applyVehicleDefaults()
        }

        // ── Separator ───────────────────────────────────────────────────────

        Rectangle {
            Layout.fillWidth: true
            height:           1
            color:            qgcPal.windowShadeLight
        }

        // ── UDP Connection ──────────────────────────────────────────────────

        QGCLabel {
            text:           qsTr("UDP Connection")
            font.pointSize: ScreenTools.mediumFontPointSize
            font.bold:      true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing:          ScreenTools.defaultFontPixelWidth

            QGCLabel {
                text: qsTr("Port:")
            }

            QGCTextField {
                id:               udpPortField
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10
                text:             QGroundControl.settingsManager.preFlightSetupSettings.udpPort.rawValue
                inputMethodHints: Qt.ImhDigitsOnly
                readOnly:         !root._udpEditMode
                enabled:          root._udpEditMode
                validator:        IntValidator { bottom: 1; top: 65535 }
            }

            QGCButton {
                text: root._udpEditMode ? qsTr("Done") : qsTr("Edit")
                onClicked: {
                    root._udpEditMode = !root._udpEditMode
                    if (!root._udpEditMode) {
                        // User finished editing — apply the new port and recheck for vehicle
                        _applyUdpPortAndRecheck()
                    }
                }
            }
        }

        // ── Separator ───────────────────────────────────────────────────────

        Rectangle {
            Layout.fillWidth: true
            height:           1
            color:            qgcPal.windowShadeLight
        }

        // ── Failsafe Mode ───────────────────────────────────────────────────

        QGCLabel {
            text:           qsTr("Failsafe Mode")
            font.pointSize: ScreenTools.mediumFontPointSize
            font.bold:      true
        }

        QGCLabel {
            text:      qsTr("Applied to ArduPilot vehicles on connect")
            color:     qgcPal.colorGrey
            wrapMode:  Text.WordWrap
            Layout.fillWidth: true
        }

        ButtonGroup { id: failsafeModeGroup }

        QGCRadioButton {
            id:      rallyPointRadio
            text:    qsTr("Rally Point — RTL using rally point")
            checked: root._selectedFailsafeMode === 0
            ButtonGroup.group: failsafeModeGroup
            onCheckedChanged: if (checked) root._selectedFailsafeMode = 0
        }

        QGCLabel {
            visible:          root._selectedFailsafeMode === 0
            text:             qsTr("⚠ Remember to set your rally point before flight")
            color:            qgcPal.colorOrange
            wrapMode:         Text.WordWrap
            Layout.fillWidth: true
        }

        QGCRadioButton {
            id:      rtlHomeRadio
            text:    qsTr("RTL Home — Return to launch point")
            checked: root._selectedFailsafeMode === 1
            ButtonGroup.group: failsafeModeGroup
            onCheckedChanged: if (checked) root._selectedFailsafeMode = 1
        }

        QGCRadioButton {
            id:      landRadio
            text:    qsTr("Land — Descend and land at current position")
            checked: root._selectedFailsafeMode === 2
            ButtonGroup.group: failsafeModeGroup
            onCheckedChanged: if (checked) root._selectedFailsafeMode = 2
        }

        // Loiter time before landing (applies to Rally Point and RTL Home modes)
        RowLayout {
            Layout.fillWidth: true
            visible:          root._selectedFailsafeMode === 0 || root._selectedFailsafeMode === 1
            spacing:          ScreenTools.defaultFontPixelWidth

            QGCLabel {
                text: qsTr("Loiter before landing:")
            }

            QGCTextField {
                id:                 loiterTimeField
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8
                text:               QGroundControl.settingsManager.preFlightSetupSettings.loiterTime.rawValue
                inputMethodHints:   Qt.ImhDigitsOnly
                validator:          IntValidator { bottom: 0; top: 300 }
            }

            QGCLabel {
                text: qsTr("seconds")
            }
        }

        // ── Separator ───────────────────────────────────────────────────────

        Rectangle {
            Layout.fillWidth: true
            height:           1
            color:            qgcPal.windowShadeLight
        }

        // ── Checklist ───────────────────────────────────────────────────────

        QGCLabel {
            text:           qsTr("Pre-Flight Checklist")
            font.pointSize: ScreenTools.mediumFontPointSize
            font.bold:      true
        }

        QGCCheckBox {
            id:      checklistCheckBox
            text:    qsTr("Enable pre-flight checklist")
            checked: QGroundControl.settingsManager.preFlightSetupSettings.checklistEnabled.rawValue
        }

        QGCComboBox {
            id:               checklistComboBox
            Layout.fillWidth: true
            enabled:          checklistCheckBox.checked && checklistFileManager.availableChecklists.length > 0
            model:            checklistFileManager.availableChecklists.length > 0
                                  ? checklistFileManager.availableChecklists
                                  : [qsTr("No checklists found")]

            Component.onCompleted: {
                const savedName = QGroundControl.settingsManager.preFlightSetupSettings.selectedChecklist.rawValue
                const idx = checklistFileManager.availableChecklists.indexOf(savedName)
                currentIndex = (idx >= 0) ? idx : 0
            }
        }
    }

    /// Apply defaults from the selected vehicle config (checklist + UDP port).
    function _applyVehicleDefaults() {
        if (vehicleConfigManager.availableVehicles.length === 0 || vehicleComboBox.currentIndex < 0)
            return

        const vehicleName = vehicleConfigManager.availableVehicles[vehicleComboBox.currentIndex]

        // Default checklist from vehicle config
        const defChecklist = vehicleConfigManager.defaultChecklist(vehicleName)
        if (defChecklist.length > 0) {
            const idx = checklistFileManager.availableChecklists.indexOf(defChecklist)
            if (idx >= 0) {
                checklistComboBox.currentIndex = idx
                checklistCheckBox.checked = true
            }
        }

        // Default UDP port from vehicle config (only if not manually editing)
        const defPort = vehicleConfigManager.defaultUdpPort(vehicleName)
        if (defPort > 0 && !root._udpEditMode) {
            udpPortField.text = defPort.toString()
        }
    }

    /// Try to detect connected vehicle via BRD_SERIAL_NUM
    function _tryDetectVehicle() {
        const matched = vehicleConfigManager.detectConnectedVehicle()
        if (matched.length > 0 && matched !== root._detectedVehicle) {
            root._detectedVehicle = matched
            root._autoDetected = true

            // Auto-select the matched vehicle in the combobox
            const idx = vehicleConfigManager.availableVehicles.indexOf(matched)
            if (idx >= 0) {
                vehicleComboBox.currentIndex = idx
                // _applyVehicleDefaults fires via onCurrentIndexChanged
            }
        }
    }

    /// Apply the edited UDP port to auto-connect settings and start rechecking for a vehicle
    function _applyUdpPortAndRecheck() {
        const portVal = parseInt(udpPortField.text)
        if (isNaN(portVal) || portVal <= 0 || portVal > 65535)
            return

        // Apply port to auto-connect so LinkManager picks it up
        QGroundControl.settingsManager.autoConnectSettings.udpListenPort.rawValue = portVal

        // Reset detection state and start polling for new connection
        root._detectedVehicle = ""
        root._autoDetected = false
        recheckTimer._recheckCount = 0
        recheckTimer.start()
    }
}
