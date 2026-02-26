import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

ColumnLayout {
    property var _activeVehicle:    QGroundControl.multiVehicleManager.activeVehicle
    property var _guidedController: globals.guidedControllerFlyView

    QGCButton {
        Layout.fillWidth: true
        text:             qsTr("Start Mission")
        enabled:          _guidedController.showStartMission
        onClicked: {
            dropPanel.hide()
            _guidedController.confirmAction(_guidedController.actionStartMission)
        }
    }

    QGCButton {
        Layout.fillWidth: true
        text:             qsTr("Continue Mission")
        enabled:          _guidedController.showContinueMission
        onClicked: {
            dropPanel.hide()
            _guidedController.confirmAction(_guidedController.actionContinueMission)
        }
    }

    QGCButton {
        Layout.fillWidth: true
        text:             qsTr("Clear Mission")
        enabled:          _activeVehicle
        onClicked: {
            dropPanel.hide()
            _activeVehicle.clearMission()
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height:           1
        color:            qgcPal.groupBorder
    }

    QGCLabel {
        text:           qsTr("Patterns")
        font.bold:      true
        font.pointSize: ScreenTools.smallFontPointSize
    }

    QGCButton {
        Layout.fillWidth: true
        text:             qsTr("Figure 8")
        enabled:          _activeVehicle
        onClicked: {
            dropPanel.hide()
            console.log("Auto: Figure 8 pattern placeholder")
        }
    }

    QGCButton {
        Layout.fillWidth: true
        text:             qsTr("Orbit")
        enabled:          _activeVehicle
        onClicked: {
            dropPanel.hide()
            console.log("Auto: Orbit pattern placeholder")
        }
    }

    QGCButton {
        Layout.fillWidth: true
        text:             qsTr("Survey")
        enabled:          _activeVehicle
        onClicked: {
            dropPanel.hide()
            console.log("Auto: Survey pattern placeholder")
        }
    }

    QGCPalette { id: qgcPal }
}
