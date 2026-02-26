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
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id:     control
    width:  parent.width
    height: ScreenTools.toolbarHeight
    color:  "transparent"

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool   _communicationLost: _activeVehicle ? _activeVehicle.vehicleLinkManager.communicationLost : false
    property color  _mainStatusBGColor: "#23291a"
    property real   _leftRightMargin:   ScreenTools.defaultFontPixelWidth * 0.75

    function dropMainStatusIndicatorTool() {
        mainStatusIndicator.dropMainStatusIndicator();
    }

    QGCPalette { id: qgcPal }

    /// Bottom single pixel divider
    Rectangle {
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        height:         1
        color:          qgcPal.toolbarDivider
    }

    Rectangle {
        id:             gradientBackground
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        width:          mainStatusLayout.width
        opacity:        qgcPal.windowTransparent.a

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: _mainStatusBGColor }
            //GradientStop { position: qgcButton.x + qgcButton.width; color: _mainStatusBGColor }
            GradientStop { position: 1; color: qgcPal.window }
        }
    }

    Rectangle {
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        anchors.left:   gradientBackground.right
        anchors.right:  parent.right
        color:          qgcPal.windowTransparent
    }

    RowLayout {
        id:                     mainLayout
        anchors.bottomMargin:   1
        anchors.rightMargin:    control._leftRightMargin
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        anchors.left:           parent.left
        anchors.right:          parent.right
        spacing:                ScreenTools.defaultFontPixelWidth

        RowLayout {
            id:                 leftStatusLayout
            Layout.fillHeight:  true
            Layout.alignment:   Qt.AlignLeft
            spacing:            ScreenTools.defaultFontPixelWidth * 2

            RowLayout {
                id:                 mainStatusLayout
                Layout.fillHeight:  true
                spacing:            0

                QGCToolBarButton {
                    id:                 qgcButton
                    Layout.fillHeight:  true
                    icon.source:        "/res/menuicon.png"
                    logo:               true
                    onClicked:          mainWindow.showToolSelectDialog()
                }

                MainStatusIndicator {
                    id:                 mainStatusIndicator
                    Layout.fillHeight:  true
                }
            }

            QGCButton {
                id:         disconnectButton
                text:       qsTr("Disconnect")
                onClicked:  _activeVehicle.closeVehicle()
                visible:    _activeVehicle && _communicationLost
            }

            FlightModeIndicator {
                Layout.fillHeight:  true
                visible:            _activeVehicle
            }

            Rectangle {
                id:                 displayJoystickButton
                Layout.fillHeight:  true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.3
                Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.3
                width:              displayJoystickLabel.width + ScreenTools.defaultFontPixelWidth * 2
                radius:             ScreenTools.defaultFontPixelWidth / 2
                color:              _displayJoystickEnabled ? "#2e7d32" : "#c62828"
                visible:            _activeVehicle

                property bool _displayJoystickEnabled: QGroundControl.settingsManager.appSettings.virtualJoystick.rawValue

                QGCLabel {
                    id:                     displayJoystickLabel
                    anchors.centerIn:       parent
                    text:                   qsTr("Display\nJoystick")
                    color:                  "white"
                    font.pointSize:         ScreenTools.smallFontPointSize
                    horizontalAlignment:    Text.AlignHCenter
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        QGroundControl.settingsManager.appSettings.virtualJoystick.rawValue =
                            !QGroundControl.settingsManager.appSettings.virtualJoystick.rawValue
                    }
                }
            }

            Rectangle {
                id:                 usbJoystickButton
                Layout.fillHeight:  true
                Layout.topMargin:   ScreenTools.defaultFontPixelHeight * 0.3
                Layout.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.3
                width:              usbJoystickLabel.width + ScreenTools.defaultFontPixelWidth * 2
                radius:             ScreenTools.defaultFontPixelWidth / 2
                color:              {
                    if (_activeVehicle && _activeVehicle.joystickEnabled)
                        return "#2e7d32"
                    if (joystickManager.activeJoystick && !joystickManager.activeJoystick.calibrated)
                        return "#e65100"
                    return "#c62828"
                }
                visible:            _activeVehicle

                QGCLabel {
                    id:                     usbJoystickLabel
                    anchors.centerIn:       parent
                    text:                   qsTr("USB\nJoystick")
                    color:                  "white"
                    font.pointSize:         ScreenTools.smallFontPointSize
                    horizontalAlignment:    Text.AlignHCenter
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked:    usbJoystickPopup.open()
                }
            }
        }

        QGCFlickable {
            id:                     indicatorsFlickable
            Layout.alignment:       Qt.AlignRight
            Layout.fillHeight:      true
            Layout.preferredWidth:  Math.min(contentWidth, availableWidth)
            contentWidth:           toolIndicators.width
            flickableDirection:     Flickable.HorizontalFlick

            property real availableWidth: mainLayout.width - leftStatusLayout.width

            FlyViewToolBarIndicators { id: toolIndicators }
        }
    }

    ParameterDownloadProgress {
        anchors.fill: parent
    }

    Popup {
        id:             usbJoystickPopup
        x:              usbJoystickButton.x
        y:              control.height
        width:          joystickPopupColumn.width + ScreenTools.defaultFontPixelWidth * 3
        height:         joystickPopupColumn.height + ScreenTools.defaultFontPixelWidth * 3
        padding:        ScreenTools.defaultFontPixelWidth * 1.5
        closePolicy:    Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color:  qgcPal.window
            border.color: qgcPal.groupBorder
            radius: ScreenTools.defaultFontPixelWidth / 2
        }

        ColumnLayout {
            id:         joystickPopupColumn
            spacing:    ScreenTools.defaultFontPixelHeight * 0.5

            property var  _activeJoystick:      joystickManager.activeJoystick
            property bool _buttonsOnly:          _activeJoystick ? _activeJoystick.axisCount === 0 : false
            property bool _requiresCalibration:  _activeJoystick ? !_activeJoystick.calibrated && !_buttonsOnly : false

            QGCLabel {
                text:           qsTr("USB Joystick")
                font.pointSize: ScreenTools.defaultFontPointSize
                font.bold:      true
            }

            QGCLabel {
                text:           qsTr("Active Joystick:")
                font.pointSize: ScreenTools.smallFontPointSize
            }

            QGCComboBox {
                id:                 joystickCombo
                Layout.fillWidth:   true
                Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 20
                model:              joystickManager.joystickNames
                currentIndex:       joystickManager.joystickNames.indexOf(joystickManager.activeJoystickName)

                onActivated: (index) => {
                    joystickManager.activeJoystickName = textAt(index)
                }

                Connections {
                    target: joystickManager
                    function onActiveJoystickNameChanged() {
                        var idx = joystickCombo.find(joystickManager.activeJoystickName)
                        if (idx >= 0) joystickCombo.currentIndex = idx
                    }
                }
            }

            QGCLabel {
                visible:        joystickPopupColumn._requiresCalibration
                text:           qsTr("Calibration required before enabling")
                color:          "orange"
                font.pointSize: ScreenTools.smallFontPointSize
                font.bold:      true
            }

            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth

                QGCButton {
                    text:       _activeVehicle && _activeVehicle.joystickEnabled ? qsTr("Disable") : qsTr("Enable")
                    Layout.fillWidth: true
                    enabled:    !joystickPopupColumn._requiresCalibration || (_activeVehicle && _activeVehicle.joystickEnabled)
                    onClicked: {
                        if (joystickManager.joystickNames.length > 0) {
                            _activeVehicle.joystickEnabled = !_activeVehicle.joystickEnabled
                            _activeVehicle.saveJoystickSettings()
                        }
                        usbJoystickPopup.close()
                    }
                }

                QGCButton {
                    text:       qsTr("Close")
                    Layout.fillWidth: true
                    onClicked:  usbJoystickPopup.close()
                }
            }

            Rectangle {
                Layout.fillWidth:   true
                height:             1
                color:              qgcPal.groupBorder
            }

            QGCButton {
                Layout.fillWidth:   true
                text:               joystickPopupColumn._requiresCalibration ? qsTr("⚠ Calibration Required") : qsTr("Calibration / Buttons...")
                highlighted:        joystickPopupColumn._requiresCalibration
                onClicked: {
                    usbJoystickPopup.close()
                    mainWindow.showVehicleConfigJoystickPage()
                }
            }
        }
    }
}
