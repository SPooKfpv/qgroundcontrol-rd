/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

ColumnLayout {
    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    QGCButton {
        Layout.fillWidth: true
        text:             qsTr("Cruise")
        enabled:          _activeVehicle
        onClicked: {
            dropPanel.hide()
            console.log("Terminal Guidance: Cruise selected")
        }
    }

    QGCButton {
        Layout.fillWidth: true
        text:             qsTr("Strike Static")
        enabled:          _activeVehicle
        onClicked: {
            dropPanel.hide()
            console.log("Terminal Guidance: Strike Static selected")
        }
    }

    QGCButton {
        Layout.fillWidth: true
        text:             qsTr("Strike Moving")
        enabled:          _activeVehicle
        onClicked: {
            dropPanel.hide()
            console.log("Terminal Guidance: Strike Moving selected")
        }
    }
}
