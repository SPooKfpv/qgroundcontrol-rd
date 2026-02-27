import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

ColumnLayout {
    property var  _activeVehicle:  QGroundControl.multiVehicleManager.activeVehicle
    property var  _settings:       QGroundControl.settingsManager.preFlightSetupSettings
    property int  _failsafeMode:   _settings.failsafeMode.rawValue
    property var  _rallyController: globals.planMasterControllerFlyView
                                        ? globals.planMasterControllerFlyView.rallyPointController
                                        : null

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    // ── Failsafe Mode ──

    QGCLabel {
        text:      qsTr("Failsafe Mode")
        font.bold: true
    }

    ButtonGroup { id: failsafeModeGroup }

    QGCRadioButton {
        text:    qsTr("Rally Point — RTL using rally point")
        checked: _failsafeMode === 0
        ButtonGroup.group: failsafeModeGroup
        onCheckedChanged: if (checked) _applyFailsafe(0)
    }

    QGCLabel {
        visible:          _failsafeMode === 0
        text:             qsTr("⚠ Remember to set your rally point before flight")
        color:            qgcPal.colorOrange
        wrapMode:         Text.WordWrap
        Layout.fillWidth: true
    }

    QGCRadioButton {
        text:    qsTr("RTL Home — Return to launch point")
        checked: _failsafeMode === 1
        ButtonGroup.group: failsafeModeGroup
        onCheckedChanged: if (checked) _applyFailsafe(1)
    }

    QGCRadioButton {
        text:    qsTr("Land — Descend and land at current position")
        checked: _failsafeMode === 2
        ButtonGroup.group: failsafeModeGroup
        onCheckedChanged: if (checked) _applyFailsafe(2)
    }

    // Loiter time before landing (Rally Point and RTL Home modes)
    RowLayout {
        Layout.fillWidth: true
        visible:          _failsafeMode === 0 || _failsafeMode === 1
        spacing:          ScreenTools.defaultFontPixelWidth

        QGCLabel {
            text: qsTr("Loiter before landing:")
        }

        QGCTextField {
            id:                 loiterTimeField
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8
            text:               _settings.loiterTime.rawValue
            inputMethodHints:   Qt.ImhDigitsOnly
            validator:          IntValidator { bottom: 0; top: 300 }
            onEditingFinished:  _applyLoiterTime()
        }

        QGCLabel {
            text: qsTr("sec")
        }
    }

    // ── Separator ──

    Rectangle {
        Layout.fillWidth: true
        height:           1
        color:            qgcPal.groupBorder
    }

    // ── Rally Points ──

    QGCLabel {
        text:      qsTr("Rally Points")
        font.bold: true
    }

    QGCLabel {
        text:             _rallyController ? qsTr("%1 rally point(s) set").arg(_rallyController.points.count) : qsTr("---")
        font.pointSize:   ScreenTools.smallFontPointSize
        Layout.fillWidth: true
    }

    QGCButton {
        Layout.fillWidth: true
        text:             qsTr("Clear Rally Points")
        enabled:          _rallyController && _rallyController.points.count > 0
        onClicked: {
            while (_rallyController.points.count > 0) {
                _rallyController.removePoint(_rallyController.points.get(0))
            }
            _rallyController.syncToVehicle()
        }
    }

    // ── Helpers ──

    function _applyFailsafe(mode) {
        _settings.failsafeMode.rawValue = mode

        if (!_activeVehicle || !_activeVehicle.apmFirmware())
            return

        var paramMgr = _activeVehicle.parameterManager
        if (!paramMgr || !paramMgr.parametersReady)
            return

        // Map mode to ArduPilot FS_THR_ENABLE value: 1 = RTL, 5 = Land
        var fsThrValue = (mode === 2) ? 5 : 1

        if (paramMgr.parameterExists(-1, "FS_THR_ENABLE")) {
            paramMgr.getParameter(-1, "FS_THR_ENABLE").rawValue = fsThrValue
        }

        // Rally Point mode: enable RALLY_ENABLE
        if (mode === 0) {
            if (paramMgr.parameterExists(-1, "RALLY_ENABLE")) {
                paramMgr.getParameter(-1, "RALLY_ENABLE").rawValue = 1
            }
        }

        // Apply loiter time for RTL modes
        if (mode === 0 || mode === 1) {
            _applyLoiterTime()
        }
    }

    function _applyLoiterTime() {
        var secs = parseInt(loiterTimeField.text)
        if (isNaN(secs) || secs < 0) secs = 30
        _settings.loiterTime.rawValue = secs

        if (!_activeVehicle || !_activeVehicle.apmFirmware())
            return

        var paramMgr = _activeVehicle.parameterManager
        if (!paramMgr || !paramMgr.parametersReady)
            return

        if (paramMgr.parameterExists(-1, "RTL_LOIT_TIME")) {
            paramMgr.getParameter(-1, "RTL_LOIT_TIME").rawValue = secs * 1000
        }
    }
}
