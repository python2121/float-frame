/*
 * SPDX-FileCopyrightText: 2022 George Florea Bănuș <georgefb899@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import org.kde.ki18n

import org.kde.haruna

Loader {
    id: root

    required property MpvVideo m_mpv

    function open() : void {
        if (!root.active) {
            root.active = true
            root.loaded.connect(function() {
                root.open()
            })
            return
        }

        const contextMenu = root.item as Menu
        contextMenu.popup()
    }

    function close() : void {
        root.active = false
    }

    // Right-click while the menu is showing closes it instead of reopening it
    // at the new position. Depending on the style, the press outside may already
    // have started closing the menu (exit transition running) or just closed it,
    // so both count as "showing".
    function toggle() : void {
        const menu = root.item as Menu
        const isShowing = root.active && menu !== null && menu.visible
        const justClosed = Date.now() - root.closedAt < 200
        if (isShowing || justClosed) {
            root.close()
            return
        }
        root.open()
    }

    // Date.now() of the last close, see toggle()
    property double closedAt: 0

    active: false
    asynchronous: true
    sourceComponent: Menu {

        onClosed: {
            root.closedAt = Date.now()
            root.active = false
        }

        MenuItem { action: HarunaApp.actions.openFileAction }
        MenuItem {
            action: HarunaApp.actions.toggleChromelessAction
            text: {
                const mainWindow = Window.window as Main
                return mainWindow?.chromeless
                        ? KI18n.i18nc("@action:inmenu", "Add Chrome")
                        : KI18n.i18nc("@action:inmenu", "Remove Chrome")
            }
        }

        MenuSeparator {}

        MenuItem { action: HarunaApp.actions.toggleQuickSettingsAction }
        MenuItem { action: HarunaApp.actions.cropToContentAction }
        MenuItem { action: HarunaApp.actions.fitWindowToVideoAction }
        MenuItem {
            action: HarunaApp.actions.resetCropAction
            visible: root.m_mpv.hasCrop()
            height: visible ? implicitHeight : 0
        }

        MenuSeparator {}

        MenuItem { action: HarunaApp.actions.playPauseAction }
        MenuItem { action: HarunaApp.actions.playNextAction }
        MenuItem { action: HarunaApp.actions.playPreviousAction }
        Menu {
            title: KI18n.i18nc("@title:menu", "Playback Speed")
            MenuItem { action: HarunaApp.actions.playbackSpeedIncreaseAction }
            MenuItem { action: HarunaApp.actions.playbackSpeedDecreaseAction }
            MenuItem { action: HarunaApp.actions.playbackSpeedResetAction }
        }

        MenuSeparator {}

        MenuItem { action: HarunaApp.actions.openUrlAction }

        MenuSeparator {}

        VideoMenu {}
        AudioMenu {
            m_mpv: root.m_mpv
        }
        SubtitlesMenu {
            m_mpv: root.m_mpv
        }

        MenuSeparator {}

        MenuItem { action: HarunaApp.actions.configureAction }

        MenuSeparator {}

        MenuItem { action: HarunaApp.actions.quitApplicationAction }
    }
}