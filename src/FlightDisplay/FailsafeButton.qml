import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightDisplay

ToolStripAction {
    text:       qsTr("Failsafe")
    iconSource: "/res/action.svg"
    visible:    true
    enabled:    true

    dropPanelComponent: Component {
        FailsafePanel { }
    }
}
