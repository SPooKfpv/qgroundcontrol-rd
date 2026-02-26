import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightDisplay

ToolStripAction {
    text:       qsTr("Auto")
    iconSource: "/res/action.svg"
    visible:    QGroundControl.multiVehicleManager.activeVehicle
    enabled:    true

    dropPanelComponent: Component {
        AutoMissionPanel { }
    }
}
