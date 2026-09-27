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
            // after the inline items (hidden ones included), before the secondary submenu
            root.insertMenu(root.m_mpv.subtitleTracksModel.rowCount, root.allPrimaryTracksMenu)
            root.allTracksMenuShown = true
        } else if (!root.hasMoreTracks && root.allTracksMenuShown) {
            root.removeMenu(root.allPrimaryTracksMenu)
            root.allTracksMenuShown = false
        }
    }
    onHasMoreTracksChanged: syncAllTracksMenu()
    Component.onCompleted: syncAllTracksMenu()

    title: KI18n.i18nc("@title:menu", "&Subtitles")

    Instantiator {
        model: root.m_mpv.subtitleTracksModel
        delegate: MenuItem {
            id: inlineTrack

            required property int index
            required property int trackId
            required property string displayText

            visible: inlineTrack.index < root.inlineTrackCount
            height: visible ? implicitHeight : 0
            checkable: true
            checked: inlineTrack.trackId === root.m_mpv.subtitleId
            enabled: inlineTrack.trackId !== root.m_mpv.secondarySubtitleId || inlineTrack.trackId === 0
            text: inlineTrack.displayText
            onTriggered: {
                root.m_mpv.subtitleId = inlineTrack.trackId === root.m_mpv.subtitleId ? -1 : inlineTrack.trackId
            }
        }
        onObjectAdded: function(index, object) { root.insertItem(index, object) }
        onObjectRemoved: function(index, object) { root.removeItem(object) }
    }

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
