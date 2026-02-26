/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include <QtQuick/QQuickWindow>
#include <QtWidgets/QApplication>

#include "QGCApplication.h"
#include "QGCCommandLineParser.h"
#include "QGCLogging.h"

#ifdef Q_OS_WIN
#include <windows.h>
#include <dwmapi.h>
#if !defined(NDEBUG)
#include <cstdio>
#endif
#endif
#include "Platform.h"
#include "NTRIP.h"
#include "SplashScreen.h"

#if !defined(Q_OS_ANDROID) && !defined(Q_OS_IOS)
    #include <QtWidgets/QMessageBox>
    #include "RunGuard.h"
#endif

#ifdef Q_OS_LINUX
    #include <unistd.h>
    #include <sys/types.h>
#endif

#ifdef QGC_UNITTEST_BUILD
    #include "UnitTestList.h"
#endif

int main(int argc, char *argv[])
{
#if defined(Q_OS_WIN) && !defined(NDEBUG)
    // Attach to parent console (if launched from cmd/terminal) so Qt
    // debug/warning/critical messages are visible. When launched from Qt Creator,
    // messages appear in the Application Output pane via OutputDebugString.
    if (AttachConsole(ATTACH_PARENT_PROCESS)) {
        (void)freopen("CONOUT$", "w", stdout);
        (void)freopen("CONOUT$", "w", stderr);
    }
#endif
#if 0
    // Useful for debugging specific unit tests
    char argument1[] = "--unittest:ParameterManagerTest";
    char argument2[] = "--logging:FactSystem.ParameterManager,Utilities.QGCStateMachine";
    char *newArgv[] = { argv[0], argument1, argument2 };
    argc = 3;
    argv = newArgv;
#endif

#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
    if (::getuid() == 0) {
        const QApplication errorApp(argc, argv);
        // QErrorMessage
        (void) QMessageBox::critical(nullptr,
                                     QCoreApplication::translate("main", "Error"),
                                     QCoreApplication::translate("main", "You are running %1 as root. "
                                                                         "You should not do this since it will cause other issues with %1. "
                                                                         "%1 will now exit.<br/><br/>").arg(QGC_APP_DISPLAY_NAME));
        return -1;
    }
#endif

    QGCCommandLineParser::CommandLineParseResult args;
    {
        const QCoreApplication pre(argc, argv);
        QCoreApplication::setApplicationName(QStringLiteral(QGC_APP_DISPLAY_NAME));
        QCoreApplication::setApplicationVersion(QStringLiteral(QGC_APP_VERSION_STR));
        args = QGCCommandLineParser::parseCommandLine();
        if (args.statusCode == QGCCommandLineParser::CommandLineParseResult::Status::Error) {
            const QString errorMessage = args.errorString.value_or(QStringLiteral("Unknown error occurred"));
            qCritical() << qPrintable(errorMessage);
            // TODO: QCommandLineParser::showMessageAndExit(QCommandLineParser::MessageType::Error) - Qt6.9
            return 1;
        }
    }

#if !defined(Q_OS_ANDROID) && !defined(Q_OS_IOS)
    const QString runguardString = QStringLiteral("%1 RunGuardKey").arg(QStringLiteral(QGC_APP_NAME));
    RunGuard guard(runguardString);
    if (!args.allowMultiple) {
        if (!guard.tryToRun()) {
            const QApplication errorApp(argc, argv);
            (void) QMessageBox::critical(nullptr,
                QCoreApplication::translate("main", "Error"),
                QCoreApplication::translate("main", "A second instance of %1 is already running. "
                                                    "Please close the other instance and try again.").arg(QStringLiteral(QGC_APP_NAME)));
            return -1;
        }
    }
#endif

    // Early platform setup before Qt app construction
    Platform::setupPreApp(args);

    QGCApplication app(argc, argv, args);

    QGCLogging::installHandler();

    // Late platform setup after app and logging exist
    Platform::setupPostApp();

    // Show splash screen before initializing (hides main window until done)
    SplashScreen *splash = nullptr;
    if (!args.runningUnitTests && !args.simpleBootTest) {
        splash = new SplashScreen();
        splash->start();
    }

    app.init();

    // Hide the main window until splash finishes
    if (splash) {
        QQuickWindow *mainWindow = app.mainRootWindow();
        if (mainWindow) {
            mainWindow->setVisible(false);
            QObject::connect(splash, &SplashScreen::finished, mainWindow, [mainWindow]() {
                mainWindow->setVisible(true);
            });
#ifdef Q_OS_WIN
            // Set Windows 11 title bar and border color to match app branding
            if (HWND hwnd = reinterpret_cast<HWND>(mainWindow->winId())) {
                constexpr DWORD DWMWA_BORDER_COLOR_VAL  = 34;
                constexpr DWORD DWMWA_CAPTION_COLOR_VAL = 35;
                COLORREF color = RGB(0x23, 0x29, 0x1a); // #23291a
                DwmSetWindowAttribute(hwnd, DWMWA_CAPTION_COLOR_VAL, &color, sizeof(color));
                DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR_VAL,  &color, sizeof(color));
            }
#endif
        }
    }

    int exitCode = 0;
    if (args.runningUnitTests) {
#ifdef QGC_UNITTEST_BUILD
        exitCode = QGCUnitTest::runTests(args.stressUnitTests, args.unitTests);
#endif
    } else if (!args.simpleBootTest) {
        exitCode = app.exec();
    }

    app.shutdown();

    qDebug() << "Exiting main";
    return exitCode;
}
