/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QObject>
#include <QtCore/QSet>

/// Listens for ArduPilot vehicles connecting and applies the stored failsafe
/// mode from PreFlightSetupSettings to the vehicle's MAVLink parameters.
///
/// Only applied on the FIRST connect per vehicle ID per session to avoid
/// overwriting manual parameter changes on reconnect.
class PreFlightSetupApplier : public QObject
{
    Q_OBJECT

public:
    explicit PreFlightSetupApplier(QObject *parent = nullptr);

private slots:
    void _parameterReadyVehicleAvailableChanged(bool parameterReadyVehicleAvailable);

private:
    void _applyFailsafeToVehicle();
    void _applyUdpPort();

    QSet<int> _appliedVehicleIds;   ///< Tracks vehicle IDs already configured this session
};
