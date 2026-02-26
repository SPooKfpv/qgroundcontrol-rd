/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "ThemeLoader.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonParseError>

QGC_LOGGING_CATEGORY(ThemeLoaderLog, "qgc.qmlcontrols.themeloader")

namespace ThemeLoader
{

static QJsonObject s_theme;
static bool s_loaded = false;

static QString _themeFilePath()
{
    // Look for config/theme.json next to the executable
    const QString appDir = QCoreApplication::applicationDirPath();
    const QStringList candidates = {
        appDir + QStringLiteral("/config/theme.json"),
        appDir + QStringLiteral("/theme.json"),
        appDir + QStringLiteral("/../config/theme.json"),
    };

    for (const QString &path : candidates) {
        if (QFile::exists(path)) {
            return QDir::cleanPath(path);
        }
    }
    return QString();
}

static void _load()
{
    s_loaded = true;
    s_theme = QJsonObject();

    const QString path = _themeFilePath();
    if (path.isEmpty()) {
        qCInfo(ThemeLoaderLog) << "No theme.json found, using built-in defaults";
        return;
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qCWarning(ThemeLoaderLog) << "Cannot open theme file:" << path << file.errorString();
        return;
    }

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &parseError);
    file.close();

    if (parseError.error != QJsonParseError::NoError) {
        qCWarning(ThemeLoaderLog) << "Theme JSON parse error at offset" << parseError.offset << ":" << parseError.errorString();
        return;
    }

    if (!doc.isObject()) {
        qCWarning(ThemeLoaderLog) << "Theme JSON root is not an object";
        return;
    }

    s_theme = doc.object();
    qCInfo(ThemeLoaderLog) << "Loaded theme from" << path;
}

const QJsonObject &theme()
{
    if (!s_loaded) {
        _load();
    }
    return s_theme;
}

QJsonObject colors()
{
    return theme().value(QStringLiteral("colors")).toObject();
}

QJsonObject fonts()
{
    return theme().value(QStringLiteral("fonts")).toObject();
}

void reload()
{
    s_loaded = false;
    (void)theme();
}

} // namespace ThemeLoader
