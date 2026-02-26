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

/// Scans config/checklists/ for JSON checklist files and exposes them to QML.
/// Instantiate from QML as ChecklistFileManager {} to access available checklists.
class ChecklistFileManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QStringList availableChecklists READ availableChecklists NOTIFY availableChecklistsChanged)

public:
    explicit ChecklistFileManager(QObject *parent = nullptr);

    /// Returns list of checklist names (filenames without .json extension) found in config/checklists/.
    QStringList availableChecklists() const { return _availableChecklists; }

    /// Loads and returns the JSON object for the named checklist. Returns empty QJsonObject on error.
    Q_INVOKABLE QJsonObject loadChecklist(const QString &name) const;

    /// Re-scans the config/checklists/ directory and updates the available list.
    Q_INVOKABLE void refresh();

signals:
    void availableChecklistsChanged();

private:
    void _scan();
    static QString _resolveChecklistsDir();

    QStringList _availableChecklists;
    QString     _checklistsDir;   ///< Cached resolved directory path (set by _scan())
};
