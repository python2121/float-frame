/*
 * SPDX-FileCopyrightText: 2020 George Florea Bănuș <georgefb899@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include <QApplication>
#include <QCommandLineParser>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickStyle>
#include <QQuickWindow>

#include <KLocalizedQmlContext>
#include <KLocalizedString>

#include <KDSingleApplication>

#include <QDateTime>

#include "application.h"
#include "commandlineoptions.h"
#include "generalsettings.h"
#include "thumbnailimageprovider.h"

#ifdef QT_DEBUG
#include <QElapsedTimer>
#endif

using namespace Qt::StringLiterals;

static const auto INITIAL_STYLE = QQuickStyle::name();

int main(int argc, char *argv[])
{
#ifdef QT_DEBUG
    QElapsedTimer timer;
    timer.start();
#endif
    qSetMessagePattern(u"%{function}() : %{message}\n"_s);

    QApplication::setOrganizationName(u"Float Frame"_s);
    QApplication::setApplicationName(u"floatframe"_s);
    QApplication::setOrganizationDomain(u"python2121.github.io"_s);
    QApplication::setApplicationDisplayName(u"Float Frame"_s);
    QApplication::setApplicationVersion(Application::version());

    // required by mpv
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
    // The chromeless window is transparent around its visible frame (the
    // resize band, see Main.qml frameMargin); that needs an alpha channel.
    QQuickWindow::setDefaultAlphaBuffer(true);

    QIcon::setFallbackThemeName(u"breeze"_s);

    QApplication qApplication(argc, argv);
    if (qEnvironmentVariableIsSet("FLOATFRAME_STARTUP_TRACE")) {
        fprintf(stderr, "FF-T qapplication %lld\n", static_cast<long long>(QDateTime::currentMSecsSinceEpoch()));
    }
    QApplication::setWindowIcon(QIcon::fromTheme(u"io.github.python2121.FloatFrame"_s));

    bool handledByQPT = INITIAL_STYLE != QQuickStyle::name();
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE") && !handledByQPT) {
        QQuickStyle::setStyle(u"org.kde.desktop"_s);
        QQuickStyle::setFallbackStyle(u"Fusion"_s);
    }

    auto *application = Application::instance();

    KDSingleApplication kdsApp;
    if (kdsApp.isPrimaryInstance()) {
        QObject::connect(&kdsApp, &KDSingleApplication::messageReceived, &qApplication, [=](const QByteArray &message) {
            QString file;
            QString token;

            QByteArray byteArray{message};
            QDataStream dataStream(&byteArray, QIODevice::ReadOnly);
            dataStream >> file >> token;

            application->handleSecondayInstanceMessage(file.toUtf8(), token);
        });
    } else {
        if (GeneralSettings::useSingleInstance()) {
            // the shared parser knows all options; a bare QCommandLineParser would
            // reject --chromeless / --ytdl-format-selection as unknown and exit
            const QStringList positionalArguments = CommandLineOptions::instance().parser()->positionalArguments();
            if (!positionalArguments.isEmpty()) {
                const QString file = positionalArguments.constFirst();
                const QString token = qEnvironmentVariable("XDG_ACTIVATION_TOKEN");

                QByteArray byteArray;
                QDataStream dataStream(&byteArray, QIODevice::WriteOnly);
                dataStream << file << token;

                kdsApp.sendMessage(byteArray);
            }
            exit(EXIT_SUCCESS);
        }
    }

    QQmlApplicationEngine engine(&qApplication);

    KLocalization::setupLocalizedContext(&engine);

    engine.addImageProvider(u"thumbnail"_s, new ThumbnailImageProvider());
    application->trace(u"engine-load-begin"_s);
    engine.loadFromModule("org.kde.haruna", "Main");
    application->trace(u"engine-load-end"_s);

    application->setQmlEngine(&engine);

#ifdef QT_DEBUG
    qDebug() << timer.elapsed() << "ms elapsed";
#endif
    return QApplication::exec();
}
