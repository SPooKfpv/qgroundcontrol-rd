/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "ChecklistFileManager.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonParseError>

QGC_LOGGING_CATEGORY(ChecklistFileManagerLog, "qgc.qmlcontrols.checklistfilemanager")

ChecklistFileManager::ChecklistFileManager(QObject *parent)
    : QObject(parent)
{
    _scan();
}

QString ChecklistFileManager::_resolveChecklistsDir()
{
    const QString appDir = QCoreApplication::applicationDirPath();
    // Search candidates in order — same pattern as ThemeLoader
    const QStringList candidates = {
        appDir + QStringLiteral("/config/checklists"),
        appDir + QStringLiteral("/checklists"),
        appDir + QStringLiteral("/../config/checklists"),
    };

    for (const QString &path : candidates) {
        if (QDir(path).exists()) {
            return QDir::cleanPath(path);
        }
    }
    return QString();
}

void ChecklistFileManager::_scan()
{
    _checklistsDir = _resolveChecklistsDir();

    QStringList found;

    if (_checklistsDir.isEmpty()) {
        qCInfo(ChecklistFileManagerLog) << "No config/checklists/ directory found";
    } else {
        QDir dir(_checklistsDir);
        const QStringList jsonFiles = dir.entryList(QStringList() << QStringLiteral("*.json"), QDir::Files, QDir::Name);
        for (const QString &fileName : jsonFiles) {
            const QString name = QFileInfo(fileName).completeBaseName();
            found.append(name);
        }
        qCInfo(ChecklistFileManagerLog) << "Found" << found.size() << "checklist(s) in" << _checklistsDir;
    }

    if (_availableChecklists != found) {
        _availableChecklists = found;
        emit availableChecklistsChanged();
    }
}

void ChecklistFileManager::refresh()
{
    _scan();
}

QJsonObject ChecklistFileManager::loadChecklist(const QString &name) const
{
    if (name.isEmpty()) {
        return QJsonObject();
    }

    // Reject path traversal attempts — name should be a bare filename stem
    if (name.contains(QLatin1Char('/')) || name.contains(QLatin1Char('\\')) || name.contains(QStringLiteral(".."))) {
        qCWarning(ChecklistFileManagerLog) << "Invalid checklist name (path traversal rejected):" << name;
        return QJsonObject();
    }

    if (_checklistsDir.isEmpty()) {
        qCWarning(ChecklistFileManagerLog) << "No checklists directory found when trying to load:" << name;
        return QJsonObject();
    }

    const QString filePath = _checklistsDir + QStringLiteral("/") + name + QStringLiteral(".json");
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qCWarning(ChecklistFileManagerLog) << "Cannot open checklist file:" << filePath << file.errorString();
        return QJsonObject();
    }

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &parseError);
    file.close();

    if (parseError.error != QJsonParseError::NoError) {
        qCWarning(ChecklistFileManagerLog) << "Checklist JSON parse error in" << filePath
                                           << "at offset" << parseError.offset << ":" << parseError.errorString();
        return QJsonObject();
    }

    if (!doc.isObject()) {
        qCWarning(ChecklistFileManagerLog) << "Checklist JSON root is not an object:" << filePath;
        return QJsonObject();
    }

    qCDebug(ChecklistFileManagerLog) << "Loaded checklist:" << name;
    return doc.object();
}
