/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "PreFlightSetupApplier.h"
#include "AutoConnectSettings.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"
#include "ParameterManager.h"
#include "SettingsManager.h"
#include "PreFlightSetupSettings.h"
#include "QGCApplication.h"
#include "QGCLoggingCategory.h"

QGC_LOGGING_CATEGORY(PreFlightSetupApplierLog, "qgc.vehicle.preflightsetupapplier")

// ArduPilot FS_THR_ENABLE values
static constexpr int kFsThrRtl       = 1;   // RTL (used for Rally Point and RTL Home modes)
static constexpr int kFsThrLand      = 5;   // Land at current position

PreFlightSetupApplier::PreFlightSetupApplier(QObject *parent)
    : QObject(parent)
{
    _applyUdpPort();

    connect(MultiVehicleManager::instance(),
            &MultiVehicleManager::parameterReadyVehicleAvailableChanged,
            this,
            &PreFlightSetupApplier::_parameterReadyVehicleAvailableChanged);
    qCDebug(PreFlightSetupApplierLog) << "PreFlightSetupApplier initialized";
}

void PreFlightSetupApplier::_parameterReadyVehicleAvailableChanged(bool parameterReadyVehicleAvailable)
{
    if (!parameterReadyVehicleAvailable) {
        return;
    }
    _applyFailsafeToVehicle();
}

void PreFlightSetupApplier::_applyFailsafeToVehicle()
{
    Vehicle *const vehicle = MultiVehicleManager::instance()->activeVehicle();
    if (!vehicle) {
        qCWarning(PreFlightSetupApplierLog) << "No active vehicle when trying to apply failsafe";
        return;
    }

    // Verify parameters are actually ready (guards against race when multiple vehicles connect)
    if (!vehicle->parameterManager()->parametersReady()) {
        qCDebug(PreFlightSetupApplierLog) << "Parameters not ready for active vehicle id:" << vehicle->id() << "— deferring";
        return;
    }

    // Only apply to ArduPilot vehicles
    if (!vehicle->apmFirmware()) {
        qCInfo(PreFlightSetupApplierLog) << "Skipping failsafe application — not an ArduPilot vehicle (id:" << vehicle->id() << ")";
        return;
    }

    // Only apply once per vehicle ID per session to preserve manual changes on reconnect
    const int vehicleId = vehicle->id();
    if (_appliedVehicleIds.contains(vehicleId)) {
        qCDebug(PreFlightSetupApplierLog) << "Skipping failsafe — already applied to vehicle id:" << vehicleId;
        return;
    }

    PreFlightSetupSettings *const settings = SettingsManager::instance()->preFlightSetupSettings();
    const int failsafeMode = settings->failsafeMode()->rawValue().toInt();
    const int loiterTimeSec = settings->loiterTime()->rawValue().toInt();

    // Map our enum to ArduPilot FS_THR_ENABLE value
    int fsThrValue = kFsThrRtl;  // default to RTL
    switch (failsafeMode) {
    case 0:  // Rally Point — RTL using rally points
        fsThrValue = kFsThrRtl;
        break;
    case 1:  // RTL Home — standard RTL
        fsThrValue = kFsThrRtl;
        break;
    case 2:  // Land — land at current position
        fsThrValue = kFsThrLand;
        break;
    default:
        qCWarning(PreFlightSetupApplierLog) << "Unknown failsafe mode:" << failsafeMode << "— defaulting to RTL";
        break;
    }

    ParameterManager *const paramMgr = vehicle->parameterManager();

    // Apply FS_THR_ENABLE
    if (paramMgr->parameterExists(ParameterManager::defaultComponentId, QStringLiteral("FS_THR_ENABLE"))) {
        paramMgr->getParameter(ParameterManager::defaultComponentId, QStringLiteral("FS_THR_ENABLE"))->setRawValue(fsThrValue);
        qCInfo(PreFlightSetupApplierLog) << "Set FS_THR_ENABLE =" << fsThrValue << "for vehicle id:" << vehicleId;
    } else {
        qCWarning(PreFlightSetupApplierLog) << "FS_THR_ENABLE not found on vehicle id:" << vehicleId << "— skipping";
    }

    // For Rally Point and RTL Home modes, set RTL_LOIT_TIME (loiter before landing, in milliseconds)
    if (failsafeMode == 0 || failsafeMode == 1) {
        const int loiterTimeMs = loiterTimeSec * 1000;
        if (paramMgr->parameterExists(ParameterManager::defaultComponentId, QStringLiteral("RTL_LOIT_TIME"))) {
            paramMgr->getParameter(ParameterManager::defaultComponentId, QStringLiteral("RTL_LOIT_TIME"))->setRawValue(loiterTimeMs);
            qCInfo(PreFlightSetupApplierLog) << "Set RTL_LOIT_TIME =" << loiterTimeMs << "ms for vehicle id:" << vehicleId;
        } else {
            qCWarning(PreFlightSetupApplierLog) << "RTL_LOIT_TIME not found on vehicle id:" << vehicleId << "— skipping";
        }
    }

    // For Rally Point mode, also set RALLY_ENABLE=1 so RTL uses rally points
    if (failsafeMode == 0) {
        if (paramMgr->parameterExists(ParameterManager::defaultComponentId, QStringLiteral("RALLY_ENABLE"))) {
            paramMgr->getParameter(ParameterManager::defaultComponentId, QStringLiteral("RALLY_ENABLE"))->setRawValue(1);
            qCInfo(PreFlightSetupApplierLog) << "Set RALLY_ENABLE = 1 for vehicle id:" << vehicleId;
        } else {
            qCWarning(PreFlightSetupApplierLog) << "RALLY_ENABLE not found on vehicle id:" << vehicleId << "— skipping";
        }
        qgcApp()->showAppMessage(tr("Rally Point mode active — remember to set your rally point before flight."));
    }

    _appliedVehicleIds.insert(vehicleId);
    qCInfo(PreFlightSetupApplierLog) << "Failsafe applied to vehicle id:" << vehicleId << "(mode:" << failsafeMode << ")";
}

void PreFlightSetupApplier::_applyUdpPort()
{
    PreFlightSetupSettings *const pfSettings = SettingsManager::instance()->preFlightSetupSettings();
    AutoConnectSettings    *const acSettings = SettingsManager::instance()->autoConnectSettings();

    const int udpPort = pfSettings->udpPort()->rawValue().toInt();
    if (udpPort <= 0 || udpPort > 65535) {
        qCWarning(PreFlightSetupApplierLog) << "Invalid UDP port in PreFlightSetup settings:" << udpPort;
        return;
    }

    acSettings->udpListenPort()->setRawValue(udpPort);
    qCInfo(PreFlightSetupApplierLog) << "Applied UDP listen port:" << udpPort << "from PreFlightSetup settings";
}
