/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QtQmlIntegration/QtQmlIntegration>

#include "SettingsGroup.h"

/// Pre-Flight Setup Settings — persists failsafe mode, checklist enabled state, and selected checklist.
class PreFlightSetupSettings : public SettingsGroup
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("")
public:
    PreFlightSetupSettings(QObject* parent = nullptr);

    DEFINE_SETTING_NAME_GROUP()

    DEFINE_SETTINGFACT(failsafeMode)
    DEFINE_SETTINGFACT(loiterTime)
    DEFINE_SETTINGFACT(selectedVehicle)
    DEFINE_SETTINGFACT(udpPort)
    DEFINE_SETTINGFACT(checklistEnabled)
    DEFINE_SETTINGFACT(selectedChecklist)
};
