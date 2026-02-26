/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "SplashScreen.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QTimer>
#include <QtCore/QPropertyAnimation>
#include <QtGui/QPainter>
#include <QtGui/QScreen>
#include <QtWidgets/QApplication>

SplashScreen::SplashScreen(QWidget *parent)
    : QWidget(parent)
{
    setWindowFlags(Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint | Qt::SplashScreen);
    setAttribute(Qt::WA_TranslucentBackground);
    setFixedSize(kWidth, kHeight);

    // Try to load splash image from config/ next to executable
    const QString appDir = QCoreApplication::applicationDirPath();
    const QStringList candidates = {
        appDir + QStringLiteral("/config/splash.png"),
        appDir + QStringLiteral("/splash.png"),
        appDir + QStringLiteral("/../config/splash.png"),
    };

    for (const QString &path : candidates) {
        if (QFile::exists(path)) {
            _pixmap = QPixmap(path);
            if (!_pixmap.isNull()) {
                _pixmap = _pixmap.scaled(kWidth, kHeight, Qt::KeepAspectRatio, Qt::SmoothTransformation);
                break;
            }
        }
    }

    // Fallback: try built-in resource
    if (_pixmap.isNull()) {
        _pixmap = QPixmap(QStringLiteral(":/res/SplashScreen"));
        if (!_pixmap.isNull()) {
            _pixmap = _pixmap.scaled(kWidth, kHeight, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        }
    }

    // Last resort: procedurally generated dark placeholder
    if (_pixmap.isNull()) {
        _pixmap = QPixmap(kWidth, kHeight);
        _pixmap.fill(QColor("#1a1a2e"));

        QPainter p(&_pixmap);
        p.setRenderHint(QPainter::Antialiasing);

        // Border
        p.setPen(QPen(QColor("#8cb3be"), 2));
        p.drawRoundedRect(1, 1, kWidth - 2, kHeight - 2, 12, 12);

        // App name
        QFont font(QStringLiteral("Open Sans"), 28, QFont::Bold);
        p.setFont(font);
        p.setPen(QColor("#ffffff"));
        p.drawText(QRect(0, 0, kWidth, kHeight - 40), Qt::AlignCenter, QStringLiteral(QGC_APP_DISPLAY_NAME));

        // Loading text
        QFont smallFont(QStringLiteral("Open Sans"), 12);
        p.setFont(smallFont);
        p.setPen(QColor("#8cb3be"));
        p.drawText(QRect(0, kHeight - 60, kWidth, 40), Qt::AlignCenter, QStringLiteral("Loading..."));

        p.end();
    }

    // Center on primary screen
    if (const QScreen *screen = QApplication::primaryScreen()) {
        const QRect screenGeom = screen->availableGeometry();
        move(screenGeom.center() - QPoint(kWidth / 2, kHeight / 2));
    }
}

void SplashScreen::paintEvent(QPaintEvent *)
{
    QPainter painter(this);
    painter.setOpacity(_fadeOpacity);
    painter.drawPixmap(0, 0, _pixmap);
}

void SplashScreen::setFadeOpacity(qreal opacity)
{
    _fadeOpacity = opacity;
    update();
}

void SplashScreen::start()
{
    show();
    _fadeIn();
}

void SplashScreen::_fadeIn()
{
    auto *anim = new QPropertyAnimation(this, "fadeOpacity", this);
    anim->setDuration(kFadeInMs);
    anim->setStartValue(0.0);
    anim->setEndValue(1.0);
    anim->setEasingCurve(QEasingCurve::OutCubic);

    connect(anim, &QPropertyAnimation::finished, this, [this]() {
        // Hold for display duration, then fade out
        QTimer::singleShot(kDisplayMs, this, &SplashScreen::_fadeOut);
    });

    anim->start(QAbstractAnimation::DeleteWhenStopped);
}

void SplashScreen::_fadeOut()
{
    auto *anim = new QPropertyAnimation(this, "fadeOpacity", this);
    anim->setDuration(kFadeOutMs);
    anim->setStartValue(1.0);
    anim->setEndValue(0.0);
    anim->setEasingCurve(QEasingCurve::InCubic);

    connect(anim, &QPropertyAnimation::finished, this, [this]() {
        hide();
        emit finished();
        deleteLater();
    });

    anim->start(QAbstractAnimation::DeleteWhenStopped);
}
