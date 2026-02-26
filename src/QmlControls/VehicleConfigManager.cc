/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "VehicleConfigManager.h"
#include "MultiVehicleManager.h"
#include "ParameterManager.h"
#include "Vehicle.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonParseError>

QGC_LOGGING_CATEGORY(VehicleConfigManagerLog, "qgc.qmlcontrols.vehicleconfigmanager")

VehicleConfigManager::VehicleConfigManager(QObject *parent)
    : QObject(parent)
{
    _scan();
}

QString VehicleConfigManager::_resolveVehiclesDir()
{
    const QString appDir = QCoreApplication::applicationDirPath();
    const QStringList candidates = {
        appDir + QStringLiteral("/config/vehicles"),
        appDir + QStringLiteral("/vehicles"),
        appDir + QStringLiteral("/../config/vehicles"),
    };

    for (const QString &path : candidates) {
        if (QDir(path).exists()) {
            return QDir::cleanPath(path);
        }
    }
    return QString();
}

void VehicleConfigManager::_scan()
{
    _vehiclesDir = _resolveVehiclesDir();

    QStringList found;

    if (_vehiclesDir.isEmpty()) {
        qCInfo(VehicleConfigManagerLog) << "No config/vehicles/ directory found";
    } else {
        QDir dir(_vehiclesDir);
        const QStringList jsonFiles = dir.entryList(QStringList() << QStringLiteral("*.json"), QDir::Files, QDir::Name);
        for (const QString &fileName : jsonFiles) {
            found.append(QFileInfo(fileName).completeBaseName());
        }
        qCInfo(VehicleConfigManagerLog) << "Found" << found.size() << "vehicle(s) in" << _vehiclesDir;
    }

    if (_availableVehicles != found) {
        _availableVehicles = found;
        emit availableVehiclesChanged();
    }
}

void VehicleConfigManager::refresh()
{
    _scan();
}

QJsonObject VehicleConfigManager::loadVehicle(const QString &name) const
{
    if (name.isEmpty() || _vehiclesDir.isEmpty()) {
        return QJsonObject();
    }

    if (name.contains(QLatin1Char('/')) || name.contains(QLatin1Char('\\')) || name.contains(QStringLiteral(".."))) {
        qCWarning(VehicleConfigManagerLog) << "Invalid vehicle name (path traversal rejected):" << name;
        return QJsonObject();
    }

    const QString filePath = _vehiclesDir + QStringLiteral("/") + name + QStringLiteral(".json");
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qCWarning(VehicleConfigManagerLog) << "Cannot open vehicle file:" << filePath << file.errorString();
        return QJsonObject();
    }

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &parseError);
    file.close();

    if (parseError.error != QJsonParseError::NoError) {
        qCWarning(VehicleConfigManagerLog) << "Vehicle JSON parse error in" << filePath
                                           << "at offset" << parseError.offset << ":" << parseError.errorString();
        return QJsonObject();
    }

    if (!doc.isObject()) {
        qCWarning(VehicleConfigManagerLog) << "Vehicle JSON root is not an object:" << filePath;
        return QJsonObject();
    }

    return doc.object();
}

QString VehicleConfigManager::displayName(const QString &name) const
{
    const QJsonObject obj = loadVehicle(name);
    return obj.value(QStringLiteral("name")).toString(name);
}

QString VehicleConfigManager::defaultChecklist(const QString &name) const
{
    const QJsonObject obj = loadVehicle(name);
    return obj.value(QStringLiteral("defaultChecklist")).toString();
}

int VehicleConfigManager::defaultUdpPort(const QString &name) const
{
    const QJsonObject obj = loadVehicle(name);
    return obj.value(QStringLiteral("defaultUdpPort")).toInt(0);
}

int VehicleConfigManager::serialNum(const QString &name) const
{
    const QJsonObject obj = loadVehicle(name);
    return obj.value(QStringLiteral("serialNum")).toInt(-1);
}

QString VehicleConfigManager::findBySerialNum(int serialNum) const
{
    for (const QString &name : _availableVehicles) {
        const QJsonObject obj = loadVehicle(name);
        if (obj.value(QStringLiteral("serialNum")).toInt(-1) == serialNum) {
            return name;
        }
    }
    return QString();
}

QString VehicleConfigManager::detectConnectedVehicle() const
{
    Vehicle *const vehicle = MultiVehicleManager::instance()->activeVehicle();
    if (!vehicle) {
        return QString();
    }

    ParameterManager *const paramMgr = vehicle->parameterManager();
    if (!paramMgr || !paramMgr->parametersReady()) {
        return QString();
    }

    if (!paramMgr->parameterExists(ParameterManager::defaultComponentId, QStringLiteral("BRD_SERIAL_NUM"))) {
        qCDebug(VehicleConfigManagerLog) << "BRD_SERIAL_NUM not found on active vehicle";
        return QString();
    }

    const int serialNum = paramMgr->getParameter(ParameterManager::defaultComponentId,
                                                  QStringLiteral("BRD_SERIAL_NUM"))->rawValue().toInt();
    qCInfo(VehicleConfigManagerLog) << "Active vehicle BRD_SERIAL_NUM:" << serialNum;

    const QString matched = findBySerialNum(serialNum);
    if (!matched.isEmpty()) {
        qCInfo(VehicleConfigManagerLog) << "Matched vehicle config:" << matched;
    }
    return matched;
}
