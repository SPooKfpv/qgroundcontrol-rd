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
#include <QtCore/QStringList>
#include <QtCore/QJsonObject>
#include <QtQmlIntegration/QtQmlIntegration>

/// Scans config/vehicles/ for JSON vehicle config files and exposes them to QML.
class VehicleConfigManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QStringList availableVehicles READ availableVehicles NOTIFY availableVehiclesChanged)

public:
    explicit VehicleConfigManager(QObject *parent = nullptr);

    QStringList availableVehicles() const { return _availableVehicles; }

    /// Loads and returns the JSON object for the named vehicle. Returns empty QJsonObject on error.
    Q_INVOKABLE QJsonObject loadVehicle(const QString &name) const;

    /// Returns the display name from the vehicle JSON (the "name" field).
    Q_INVOKABLE QString displayName(const QString &name) const;

    /// Returns the default checklist name for a vehicle, or empty string.
    Q_INVOKABLE QString defaultChecklist(const QString &name) const;

    /// Returns the default UDP port for a vehicle, or 0 if not specified.
    Q_INVOKABLE int defaultUdpPort(const QString &name) const;

    /// Returns the serialNum from the vehicle JSON, or -1 if not specified.
    Q_INVOKABLE int serialNum(const QString &name) const;

    /// Finds a vehicle config name by BRD_SERIAL_NUM value. Returns empty string if no match.
    Q_INVOKABLE QString findBySerialNum(int serialNum) const;

    /// Reads BRD_SERIAL_NUM from the active vehicle and returns the matching vehicle config name.
    /// Returns empty string if no vehicle connected, params not ready, or no match.
    Q_INVOKABLE QString detectConnectedVehicle() const;

    Q_INVOKABLE void refresh();

signals:
    void availableVehiclesChanged();

private:
    void _scan();
    static QString _resolveVehiclesDir();

    QStringList _availableVehicles;
    QString     _vehiclesDir;
};
