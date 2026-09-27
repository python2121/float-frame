/*
 * SPDX-FileCopyrightText: 2020 George Florea Bănuș <georgefb899@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import QtQuick.Controls

import org.kde.ki18n

import org.kde.haruna

Menu {
    id: root

    required property MpvVideo m_mpv

    // Float Frame: the first subtitle tracks sit directly in this menu; the
    // full "Primary Subtitle" submenu only appears when there are more.
    readonly property int inlineTrackCount: 5
    readonly property bool hasMoreTracks: root.m_mpv.subtitleTracksModel.rowCount > inlineTrackCount

    property SubtitleTracksMenu allPrimaryTracksMenu: SubtitleTracksMenu {
        m_mpv: root.m_mpv
        isPrimarySubtitleMenu: true
        title: KI18n.i18nc("@title:menu", "All Subtitle Tracks")
    }

    property bool allTracksMenuShown: false

    function syncAllTracksMenu() : void {
        if (root.hasMoreTracks && !root.allTracksMenuShown) {
            // after the five inline rows, before the secondary submenu
            root.insertMenu(root.inlineTrackCount, root.allPrimaryTracksMenu)
            root.allTracksMenuShown = true
        } else if (!root.hasMoreTracks && root.allTracksMenuShown) {
            root.removeMenu(root.allPrimaryTracksMenu)
            root.allTracksMenuShown = false
        }
    }
    onHasMoreTracksChanged: syncAllTracksMenu()
    Component.onCompleted: syncAllTracksMenu()

    title: KI18n.i18nc("@title:menu", "&Subtitles")

    // Fixed rows bound to the model: dynamic insertion into a Menu reorders
    // badly when the track list is reset, static items cannot.
    function trackRole(row: int, role: int) : var {
        const model = root.m_mpv.subtitleTracksModel
        if (row >= model.rowCount) {
            return undefined
        }
        return model.data(model.index(row, 0), role)
    }

    component InlineTrack: MenuItem {
        id: inlineTrack

        required property int row
        // re-read when the list changes (new file or external subtitle added)
        readonly property int trackId: {
            root.m_mpv.subtitleTracksModel.rowCount; root.m_mpv.currentUrl
            const id = root.trackRole(row, TracksModel.IdRole)
            return id === undefined ? -2 : Number(id)
        }

        visible: inlineTrack.row < root.m_mpv.subtitleTracksModel.rowCount && inlineTrack.row < root.inlineTrackCount
        height: visible ? implicitHeight : 0
        checkable: true
        checked: inlineTrack.trackId === root.m_mpv.subtitleId
        enabled: inlineTrack.trackId !== root.m_mpv.secondarySubtitleId || inlineTrack.trackId === 0
        text: {
            root.m_mpv.subtitleTracksModel.rowCount; root.m_mpv.currentUrl
            const t = root.trackRole(row, TracksModel.TextRole)
            return t === undefined ? "" : String(t)
        }
        onTriggered: {
            root.m_mpv.subtitleId = inlineTrack.trackId === root.m_mpv.subtitleId ? -1 : inlineTrack.trackId
        }
    }

    InlineTrack { row: 0 }
    InlineTrack { row: 1 }
    InlineTrack { row: 2 }
    InlineTrack { row: 3 }
    InlineTrack { row: 4 }

    SubtitleTracksMenu {
        m_mpv: root.m_mpv
        isPrimarySubtitleMenu: false
        title: KI18n.i18nc("@title:menu", "Secondary Subtitle")
    }

    MenuSeparator {}

    MenuItem {
        action: HarunaApp.actions.addExternalSubtitleAction
        enabled: root.m_mpv.currentUrl.toString() !== ""
    }
    MenuItem { action: HarunaApp.actions.subtitleIncreaseFontSizeAction }
    MenuItem { action: HarunaApp.actions.subtitleDecreaseFontSizeAction }
    MenuItem { action: HarunaApp.actions.subtitleMoveUpAction }
    MenuItem { action: HarunaApp.actions.subtitleMoveDownAction }
    MenuItem { action: HarunaApp.actions.subtitleQuickenAction }
    MenuItem { action: HarunaApp.actions.subtitleDelayAction }
    MenuItem { action: HarunaApp.actions.subtitleToggleAction }
    MenuItem { action: HarunaApp.actions.subtitleCycleUpAction }
    MenuItem { action: HarunaApp.actions.subtitleCycleDownAction }
}
