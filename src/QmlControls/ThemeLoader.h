/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QJsonObject>
#include <QtCore/QLoggingCategory>

Q_DECLARE_LOGGING_CATEGORY(ThemeLoaderLog)

/// Loads and caches the user-editable theme.json config file.
/// Looks for config/theme.json next to the application executable.
/// Falls back to empty config (hardcoded defaults used) if not found.
namespace ThemeLoader
{
    /// Returns the cached theme JSON object. Loads on first call.
    const QJsonObject &theme();

    /// Returns the "colors" sub-object from the theme.
    QJsonObject colors();

    /// Returns the "fonts" sub-object from the theme.
    QJsonObject fonts();

    /// Reloads the theme from disk (useful for hot-reloading).
    void reload();
}
