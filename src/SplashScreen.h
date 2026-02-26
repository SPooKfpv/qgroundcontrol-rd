/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QtWidgets/QWidget>

class QLabel;
class QPropertyAnimation;

/// Frameless splash screen with fade-in / fade-out.
/// Shows a PNG image (or placeholder) centered on screen for a fixed duration,
/// keeping the main window hidden until the splash finishes.
class SplashScreen : public QWidget
{
    Q_OBJECT
    Q_PROPERTY(qreal fadeOpacity READ fadeOpacity WRITE setFadeOpacity)

public:
    explicit SplashScreen(QWidget *parent = nullptr);
    ~SplashScreen() override = default;

    /// Start the splash sequence. The main window should be hidden before calling this.
    /// Emits finished() when the splash is done and the main window can be shown.
    void start();

    qreal fadeOpacity() const { return _fadeOpacity; }
    void setFadeOpacity(qreal opacity);

signals:
    void finished();

protected:
    void paintEvent(QPaintEvent *event) override;

private:
    void _fadeIn();
    void _fadeOut();

    static constexpr int kFadeInMs = 500;
    static constexpr int kDisplayMs = 2000;
    static constexpr int kFadeOutMs = 500;
    static constexpr int kWidth = 600;
    static constexpr int kHeight = 250;

    QPixmap _pixmap;
    qreal   _fadeOpacity = 0.0;
};
