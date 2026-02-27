/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtCore

import QGroundControl
import QGroundControl.Controls

Item {
    property Window window

    /// The desired visibility to apply when the window is first shown (by C++).
    /// Saved here during onCompleted so we don't accidentally make the window
    /// visible before the splash screen finishes.
    property int pendingVisibility: Window.Windowed

    property bool _enabled: !ScreenTools.isMobile && !ScreenTools.fakeMobile && QGroundControl.corePlugin.options.enableSaveMainWindowPosition

    Settings {
        id:         s
        category:   "MainWindowState"

        property int x
        property int y
        property int width
        property int height
        property int visibility
    }

    function _setDefaultDesktopWindowSize() {
        window.width = Math.min(250 * Screen.pixelDensity, Screen.width);
        window.height = Math.min(150 * Screen.pixelDensity, Screen.height);
    }

    /// Apply the saved visibility state. Called from C++ (or QML) after splash finishes.
    function applyPendingVisibility() {
        if (ScreenTools.isMobile && !ScreenTools.fakeMobile) {
            window.showFullScreen()
        } else {
            window.visibility = pendingVisibility
        }
    }

    Component.onCompleted: {
        if (ScreenTools.fakeMobile) {
            window.width = ScreenTools.screenWidth
            window.height = ScreenTools.screenHeight
        } else if (ScreenTools.isMobile) {
            // Don't call showFullScreen() here — deferred to applyPendingVisibility()
            pendingVisibility = Window.FullScreen
        } else if (QGroundControl.corePlugin.options.enableSaveMainWindowPosition) {
            window.minimumWidth = Math.min(ScreenTools.defaultFontPixelWidth * 100, Screen.width)
            window.minimumHeight = Math.min(ScreenTools.defaultFontPixelWidth * 50, Screen.height)
            if (s.width && s.height) {
                window.x = s.x;
                window.y = s.y;
                window.width = s.width;
                window.height = s.height;
                // Don't set window.visibility here — deferred to applyPendingVisibility()
                pendingVisibility = s.visibility
            } else {
                _setDefaultDesktopWindowSize()
            }
        } else {
            _setDefaultDesktopWindowSize()
        }
    }

    Connections {
        target:                         window
        function onXChanged()           { if(_enabled) saveSettingsTimer.restart() }
        function onYChanged()           { if(_enabled) saveSettingsTimer.restart() }
        function onWidthChanged()       { if(_enabled) saveSettingsTimer.restart() }
        function onHeightChanged()      { if(_enabled) saveSettingsTimer.restart() }
        function onVisibilityChanged()  { if(_enabled) saveSettingsTimer.restart() }
    }

    Timer {
        id:             saveSettingsTimer
        interval:       500
        repeat:         false
        onTriggered:    saveSettings()
    }

    function saveSettings() {
        if (_enabled) {
            switch(window.visibility) {
            case ApplicationWindow.Windowed:
                s.x = window.x;
                s.y = window.y;
                s.width = window.width;
                s.height = window.height;
                s.visibility = window.visibility;
                break;
            case ApplicationWindow.FullScreen:
                s.visibility = window.visibility;
                break;
            case ApplicationWindow.Maximized:
                s.visibility = window.visibility;
                break;
            }
        }
    }
}
