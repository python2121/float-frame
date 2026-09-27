/*
 * SPDX-FileCopyrightText: 2025 George Florea Bănuș <georgefb899@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#ifndef SYSTEMUTILS_H
#define SYSTEMUTILS_H

#include <QObject>
#include <QQmlEngine>

class SystemUtils : public QObject
{
    Q_OBJECT
    QML_SINGLETON
    QML_ELEMENT
public:
    explicit SystemUtils(QObject *parent = nullptr);

    Q_INVOKABLE QStringList getFonts();
    Q_INVOKABLE QString platformName();
    Q_INVOKABLE bool isPlatformWayland();
    Q_INVOKABLE static bool isHanaInstalled();
    Q_INVOKABLE static bool openHana(const QUrl &url);
    Q_INVOKABLE static bool isMediaInfoInstalled();
    Q_INVOKABLE static bool openMediaInfo(const QUrl &url);
    // Ask the window system to start an interactive move/resize of a frameless
    // window (xdg_toplevel move/resize on Wayland). QWindow has these but they
    // are not Q_INVOKABLE, so QML cannot call them directly. `window` is any QML
    // Window, `edges` a Qt.Edges combination and `grabber` the MouseArea that
    // received the press: the compositor owns the pointer from now on and may
    // never deliver the button release, so the grabber's mouse grab is released
    // (resetting its pressed state) once the request has been sent.
    Q_INVOKABLE static bool startSystemMove(QObject *window, QObject *grabber);
    Q_INVOKABLE static bool startSystemResize(QObject *window, int edges, QObject *grabber);
};

#endif // SYSTEMUTILS_H
