/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightDisplay
import QGroundControl.FlightMap

/// Right-side panel: GStreamer video (16:9), HUD instruments, MAVLink console.
/// Width is controlled by the parent via panelWidth; a drag handle lets the user resize.
Item {
    id: _root

    property var    activeVehicle:  QGroundControl.multiVehicleManager.activeVehicle
    property real   panelWidth:     parent ? parent.width / 3 : 400
    property var    _paramMgr:     activeVehicle ? activeVehicle.parameterManager : null
    property bool   _paramsReady:  _paramMgr ? _paramMgr.parametersReady : false
    property string _serialNum:    _paramsReady && _paramMgr.parameterExists(-1, "BRD_SERIAL_NUM")
                                       ? _paramMgr.getParameter(-1, "BRD_SERIAL_NUM").rawValue.toString() : "---"
    property string _sysId:        _paramsReady && _paramMgr.parameterExists(-1, "SYSID_THISMAV")
                                       ? _paramMgr.getParameter(-1, "SYSID_THISMAV").rawValue.toString() : "---"
    property string _vehicleName:  QGroundControl.settingsManager.preFlightSetupSettings.selectedVehicle.rawValue || "---"
    property int    _udpPort:      QGroundControl.settingsManager.preFlightSetupSettings.udpPort.rawValue

    width:  panelWidth
    height: parent ? parent.height : 600

    // ── Dark background ──
    Rectangle {
        anchors.fill: parent
        color:        "#1a1a1a"
    }

    // ── Drag handle on the left edge for resizing ──
    Rectangle {
        id:     dragHandle
        width:  ScreenTools.defaultFontPixelWidth * 0.5
        height: parent.height
        color:  dragArea.containsMouse || dragArea.drag.active ? "#5a5a5a" : "#3a3a3a"
        anchors.left: parent.left

        MouseArea {
            id:             dragArea
            anchors.fill:   parent
            anchors.margins: -ScreenTools.defaultFontPixelWidth  // wider hit area
            cursorShape:    Qt.SplitHCursor
            hoverEnabled:   true
            drag.target:    null

            property real _startX
            property real _startWidth

            onPressed: (mouse) => {
                _startX     = mapToItem(_root.parent, mouse.x, 0).x
                _startWidth = _root.panelWidth
            }
            onPositionChanged: (mouse) => {
                if (pressed) {
                    var currentX = mapToItem(_root.parent, mouse.x, 0).x
                    var delta    = _startX - currentX
                    var minW     = ScreenTools.defaultFontPixelWidth * 25
                    var maxW     = _root.parent ? _root.parent.width * 0.6 : 800
                    _root.panelWidth = Math.max(minW, Math.min(maxW, _startWidth + delta))
                }
            }
        }
    }

    // ── Content column ──
    ColumnLayout {
        anchors.fill:       parent
        anchors.leftMargin: dragHandle.width
        spacing:            1

        // ── 1. Video (locked 16:9) ──
        Rectangle {
            id:              videoSection
            Layout.fillWidth: true
            Layout.preferredHeight: (width) * 9 / 16
            color:           "black"
            clip:            true

            FlightDisplayViewVideo {
                id:             sidePanelVideo
                anchors.fill:   parent
                useSmallFont:   true
                visible:        QGroundControl.videoManager.isStreamSource
            }

            // Fallback label when no stream
            QGCLabel {
                anchors.centerIn: parent
                text:             qsTr("NO VIDEO")
                color:            "white"
                font.pointSize:   ScreenTools.mediumFontPointSize
                visible:          !QGroundControl.videoManager.isStreamSource
            }
        }

        // ── 2. HUD header + instruments ──
        Rectangle {
            id:               hudSection
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 14
            color:            "#111111"

            ColumnLayout {
                anchors.fill:       parent
                anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.5
                spacing:            2

                // Vehicle identity header
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: ScreenTools.defaultFontPixelWidth
                    QGCLabel {
                        text:  qsTr("ID: %1").arg(_serialNum)
                        color: "#8cb3be"; font.bold: true
                        font.pointSize: 12
                    }
                    QGCLabel {
                        text:  _vehicleName
                        color: "white"; font.bold: true
                        font.pointSize: 12
                    }
                    QGCLabel {
                        text:  qsTr("Fleet: %1").arg(_sysId)
                        color: "#8cb3be"; font.bold: true
                        font.pointSize: 12
                    }
                    QGCLabel {
                        text:  qsTr("UDP: %1").arg(_udpPort)
                        color: "#8cb3be"; font.bold: true
                        font.pointSize: 12
                    }
                }

                // Instruments row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: ScreenTools.defaultFontPixelWidth

                    // Attitude indicator
                    QGCAttitudeWidget {
                        id:                 attitudeWidget
                        size:               Math.min(parent.height * 0.9, parent.width * 0.35)
                        vehicle:            _root.activeVehicle
                        showHeading:        true
                        Layout.alignment:   Qt.AlignVCenter
                    }

                    // Compass
                    QGCCompassWidget {
                        id:                 compassWidget
                        size:               attitudeWidget.size
                        vehicle:            _root.activeVehicle
                        Layout.alignment:   Qt.AlignVCenter
                    }

                    // Numeric telemetry
                    ColumnLayout {
                        Layout.fillWidth:   true
                        Layout.alignment:   Qt.AlignVCenter
                        spacing:            2

                        QGCLabel {
                            text:  qsTr("ALT: %1 m").arg(_root.activeVehicle ? _root.activeVehicle.altitudeRelative.rawValue.toFixed(1) : "---")
                            color: "white"
                            font.pointSize: ScreenTools.smallFontPointSize
                        }
                        QGCLabel {
                            text:  qsTr("SPD: %1 m/s").arg(_root.activeVehicle ? _root.activeVehicle.groundSpeed.rawValue.toFixed(1) : "---")
                            color: "white"
                            font.pointSize: ScreenTools.smallFontPointSize
                        }
                        QGCLabel {
                            text:  qsTr("HDG: %1°").arg(_root.activeVehicle ? _root.activeVehicle.heading.rawValue.toFixed(0) : "---")
                            color: "white"
                            font.pointSize: ScreenTools.smallFontPointSize
                        }
                        QGCLabel {
                            text:  qsTr("DIST: %1 m").arg(_root.activeVehicle ? _root.activeVehicle.distanceToHome.rawValue.toFixed(0) : "---")
                            color: "white"
                            font.pointSize: ScreenTools.smallFontPointSize
                        }
                        QGCLabel {
                            text:  qsTr("BAT: %1%").arg(_root.activeVehicle && _root.activeVehicle.batteries.count > 0
                                                          ? _root.activeVehicle.batteries.get(0).percentRemaining.rawValue.toFixed(0)
                                                          : "---")
                            color: "white"
                            font.pointSize: ScreenTools.smallFontPointSize
                        }
                    }
                }
            }
        }

        // ── 3. MAVLink message console ──
        Rectangle {
            id:               consoleSection
            Layout.fillWidth: true
            Layout.fillHeight: true
            color:            "#0a0a0a"

            ColumnLayout {
                anchors.fill:    parent
                anchors.margins: 2
                spacing:         2

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    QGCLabel {
                        text:       qsTr("MAVLink Console")
                        color:      "#8cb3be"
                        font.bold:  true
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                    Item { Layout.fillWidth: true }
                    QGCButton {
                        text:             qsTr("Clear")
                        font.pointSize:   ScreenTools.smallFontPointSize
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                        onClicked:        consoleTextArea.text = ""
                    }
                }

                // Scrollable message area
                ScrollView {
                    id:               consoleScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip:             true

                    TextArea {
                        id:               consoleTextArea
                        readOnly:         true
                        textFormat:       TextEdit.RichText
                        wrapMode:         TextArea.Wrap
                        color:            "#00ff00"
                        font.family:      "Courier"
                        font.pointSize:   12
                        background:       null
                        selectByMouse:    true

                        // Strip QGC HTML and re-wrap with our own colors
                        function formatHtml(html) {
                            // Strip QGC tags (nested <> in font style attribute)
                            var plain = html.replace(/<br\s*\/?>/gi, "\n")
                                            .replace(/<font[^"]*"[^"]*">/gi, "")
                                            .replace(/<\/font>/gi, "")
                                            .replace(/<[^>]*>/g, "")
                            // Color each line: red for Critical, green otherwise
                            var lines = plain.split("\n")
                            var result = []
                            for (var i = 0; i < lines.length; i++) {
                                var line = lines[i]
                                if (line.length === 0) continue
                                if (line.indexOf("Critical") >= 0)
                                    result.push("<font color=\"#ff4444\">" + line + "</font>")
                                else
                                    result.push("<font color=\"#00ff00\">" + line + "</font>")
                            }
                            return result.join("<br>")
                        }

                        Connections {
                            target: _root.activeVehicle ? _root.activeVehicle : null
                            function onNewFormattedMessage(formattedMessage) {
                                var colored = consoleTextArea.formatHtml(formattedMessage)
                                if (consoleTextArea.length > 0)
                                    consoleTextArea.append(colored)
                                else
                                    consoleTextArea.text = colored
                                consoleScroll.ScrollBar.vertical.position = 1.0 - consoleScroll.ScrollBar.vertical.size
                            }
                        }

                        // Load existing messages when vehicle connects
                        Component.onCompleted: {
                            if (_root.activeVehicle) {
                                consoleTextArea.text = formatHtml(_root.activeVehicle.formattedMessages)
                            }
                        }
                    }
                }
            }
        }
    }

    QGCPalette { id: qgcPal }
}
