/*
 * SPDX-FileCopyrightText: 2025 George Florea Bănuș <georgefb899@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "systemutils.h"

#include <QFontDatabase>
#include <QGuiApplication>
#include <QPointer>
#include <QQuickItem>
#include <QWindow>

#include <QtGui/qguiapplication_platform.h>
#include <qpa/qplatformwindow_p.h>

#include <wayland-client-protocol.h>

#include <KIO/ApplicationLauncherJob>
#include <KService>
#include <KWindowSystem>

using namespace Qt::StringLiterals;

SystemUtils::SystemUtils(QObject *parent)
    : QObject{parent}
{

}

QStringList SystemUtils::getFonts()
{
    return QFontDatabase::families();
}

QString SystemUtils::platformName()
{
    return QGuiApplication::platformName();
}

bool SystemUtils::isPlatformWayland()
{
    return KWindowSystem::isPlatformWayland();
}

bool SystemUtils::isHanaInstalled()
{
    auto service = KService::serviceByDesktopName(u"org.kde.hana"_s);
    if (!service) {
        return false;
    }

    return true;
}

bool SystemUtils::openHana(const QUrl &url)
{
    auto service = KService::serviceByDesktopName(u"org.kde.hana"_s);
    if (!service) {
        return false;
    }

    auto *job = new KIO::ApplicationLauncherJob(service);
    job->setUrls(QList<QUrl>() << url);
    job->start();

    return true;
}

bool SystemUtils::isMediaInfoInstalled()
{
    auto service1 = KService::serviceByDesktopName(u"net.mediaarea.MediaInfo"_s);
    if (service1) {
        return true;
    }
    auto service2 = KService::serviceByDesktopName(u"mediainfo-gui"_s);
    if (service2) {
        return true;
    }

    return false;
}

bool SystemUtils::openMediaInfo(const QUrl &url)
{
    auto service1 = KService::serviceByDesktopName(u"net.mediaarea.MediaInfo"_s);
    if (service1) {
        auto *job = new KIO::ApplicationLauncherJob(service1);
        job->setUrls(QList<QUrl>() << url);
        job->start();
        return true;
    }

    auto service2 = KService::serviceByDesktopName(u"mediainfo-gui"_s);
    if (service2) {
        auto *job = new KIO::ApplicationLauncherJob(service2);
        job->setUrls(QList<QUrl>() << url);
        job->start();
        return true;
    }

    return false;
}

// Queued so it runs after the current press/move handler has finished; the
// delivery agent would otherwise re-grab for an accepted press.
static void releaseMouseGrabLater(QObject *grabber)
{
    QPointer<QQuickItem> item = qobject_cast<QQuickItem *>(grabber);
    if (item.isNull()) {
        return;
    }
    QMetaObject::invokeMethod(
        item.data(),
        [item]() {
            if (item) {
                item->ungrabMouse();
            }
        },
        Qt::QueuedConnection);
}

bool SystemUtils::startSystemMove(QObject *window, QObject *grabber)
{
    auto *qWindow = qobject_cast<QWindow *>(window);
    if (qWindow == nullptr) {
        return false;
    }
    const bool started = qWindow->startSystemMove();
    if (started) {
        releaseMouseGrabLater(grabber);
    }
    return started;
}

bool SystemUtils::setWindowMargins(QObject *window, int margin)
{
    auto *qWindow = qobject_cast<QWindow *>(window);
    if (qWindow == nullptr || margin < 0) {
        return false;
    }
    auto *wayland = qWindow->nativeInterface<QNativeInterface::Private::QWaylandWindow>();
    if (wayland == nullptr) {
        return false;
    }
    wayland->setCustomMargins(QMargins(margin, margin, margin, margin));
    return true;
}

bool SystemUtils::setWindowOpaqueInset(QObject *window, int inset)
{
    auto *qWindow = qobject_cast<QWindow *>(window);
    if (qWindow == nullptr || inset < 0) {
        return false;
    }
    auto *waylandWindow = qWindow->nativeInterface<QNativeInterface::Private::QWaylandWindow>();
    auto *waylandApp = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>();
    if (waylandWindow == nullptr || waylandApp == nullptr) {
        return false;
    }
    wl_surface *surface = waylandWindow->surface();
    wl_compositor *compositor = waylandApp->compositor();
    if (surface == nullptr || compositor == nullptr) {
        return false;
    }
    // No client-side decoration, so the QWindow is the whole surface and its
    // logical size is what wl_region takes.
    const QRect opaque = QRect(QPoint(0, 0), qWindow->size()).marginsRemoved(QMargins(inset, inset, inset, inset));
    wl_region *region = wl_compositor_create_region(compositor);
    if (opaque.isValid()) {
        wl_region_add(region, opaque.x(), opaque.y(), opaque.width(), opaque.height());
    }
    wl_surface_set_opaque_region(surface, region);
    wl_region_destroy(region);
    // takes effect with the next commit, so make sure one comes
    qWindow->requestUpdate();
    return true;
}

bool SystemUtils::startSystemResize(QObject *window, int edges, QObject *grabber)
{
    auto *qWindow = qobject_cast<QWindow *>(window);
    if (qWindow == nullptr || edges == 0) {
        return false;
    }
    const bool started = qWindow->startSystemResize(Qt::Edges::fromInt(edges));
    if (started) {
        releaseMouseGrabLater(grabber);
    }
    return started;
}
