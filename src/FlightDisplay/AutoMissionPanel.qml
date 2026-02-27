import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

ColumnLayout {
    property var _activeVehicle:    QGroundControl.multiVehicleManager.activeVehicle
    property var _guidedController: globals.guidedControllerFlyView
    property var _refPoint:         globals.patternReferencePoint

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
            mainWindow.showMessageDialog(
                qsTr("Clear Mission"),
                qsTr("Remove all mission items and clear the mission from the vehicle?"),
                Dialog.Yes | Dialog.Cancel,
                function() {
                    globals.planMasterControllerFlyView.removeAllFromVehicle()
                    globals.planMasterControllerFlyView.missionController.setCurrentPlanViewSeqNum(0, true)
                })
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

    QGCLabel {
        text:           _refPoint ? qsTr("Ref: %1, %2").arg(_refPoint.latitude.toFixed(6)).arg(_refPoint.longitude.toFixed(6))
                                  : qsTr("No reference point set")
        font.pointSize: ScreenTools.smallFontPointSize
        color:          _refPoint ? qgcPal.text : qgcPal.colorOrange
    }

    QGCButton {
        Layout.fillWidth: true
        text:             qsTr("Figure 8")
        enabled:          _activeVehicle && _refPoint
        onClicked: {
            dropPanel.hide()
            console.log("Auto: Figure 8 pattern at ref point:", _refPoint.latitude, _refPoint.longitude)
        }
    }

    QGCButton {
        Layout.fillWidth: true
        text:             qsTr("Orbit")
        enabled:          _activeVehicle && _refPoint
        onClicked: {
            dropPanel.hide()
            console.log("Auto: Orbit pattern at ref point:", _refPoint.latitude, _refPoint.longitude)
        }
    }

    QGCButton {
        Layout.fillWidth: true
        text:             qsTr("Survey")
        enabled:          _activeVehicle && _refPoint
        onClicked: {
            dropPanel.hide()
            console.log("Auto: Survey pattern at ref point:", _refPoint.latitude, _refPoint.longitude)
        }
    }

    QGCButton {
        Layout.fillWidth: true
        text:             qsTr("Clear Reference Point")
        visible:          _refPoint
        onClicked: {
            globals.patternReferencePoint = null
        }
    }

    QGCPalette { id: qgcPal }
}
