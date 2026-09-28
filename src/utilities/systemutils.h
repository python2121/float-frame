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
    // Wayland: reserve `margin` px of the window's surface on every side as a
    // band the compositor treats as *outside* the window (it is excluded from
    // the xdg window geometry, the way client-side shadows are). Pointer
    // events in the band still reach the window, so a frameless window can
    // offer resize grab zones beyond its visible edge, like a decorated one.
    // Qt grows/shrinks the surface by the change so the area inside the band
    // keeps its size. Returns false — and changes nothing — off Wayland or
    // before the window has a native surface.
    Q_INVOKABLE static bool setWindowMargins(QObject *window, int margin);
    // Wayland: tell the compositor the window is opaque except for an `inset`
    // px band around it (the resize band above), or opaque everywhere with 0.
    // Asking for an alpha buffer makes Qt stop reporting any opaque region,
    // which costs a blend of the whole surface every frame and rules out
    // direct scanout of fullscreen video; this puts the region back. It is in
    // surface coordinates, so call it again after every resize and whenever
    // the band changes. Returns false (no change) off Wayland or before the
    // window has a surface.
    Q_INVOKABLE static bool setWindowOpaqueInset(QObject *window, int inset);
};

#endif // SYSTEMUTILS_H
