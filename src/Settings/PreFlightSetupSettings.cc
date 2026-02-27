/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "PreFlightSetupSettings.h"

// CRITICAL: The name arg "PreFlightSetup" MUST match the JSON filename prefix
// "PreFlightSetup.SettingsGroup.json". A mismatch causes exit(-1) at startup.
DECLARE_SETTINGGROUP(PreFlightSetup, "PreFlightSetup")
{
    // No additional initialization needed
}

DECLARE_SETTINGSFACT(PreFlightSetupSettings, failsafeMode)
DECLARE_SETTINGSFACT(PreFlightSetupSettings, loiterTime)
DECLARE_SETTINGSFACT(PreFlightSetupSettings, selectedVehicle)
DECLARE_SETTINGSFACT(PreFlightSetupSettings, udpPort)
DECLARE_SETTINGSFACT(PreFlightSetupSettings, checklistEnabled)
DECLARE_SETTINGSFACT(PreFlightSetupSettings, selectedChecklist)
