/*
 * SPDX-FileCopyrightText: 2026 Float Frame contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.ki18n
import org.kde.kirigami as Kirigami

import org.kde.haruna

// Cold start with nothing to play: an Open button and the last few files.
// Goes away as soon as something loads, on Escape, or via its close button
// (not on a click outside: resizing or moving the window would dismiss it).
Popup {
    id: root

    required property MpvVideo m_mpv
    property int maxRecent: 3

    modal: false
    dim: false
    closePolicy: Popup.CloseOnEscape
    anchors.centerIn: Overlay.overlay
    padding: Kirigami.Units.largeSpacing * 2
    width: Math.min(Kirigami.Units.gridUnit * 26, (Overlay.overlay?.width ?? 600) - Kirigami.Units.largeSpacing * 4)

    background: Rectangle {
        color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.94)
        radius: Kirigami.Units.cornerRadius
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
        border.width: 1
    }

    // the KDE desktop style paints button text itself, so shorten long names
    // here instead of eliding inside a custom content item
    function shortened(name: string, maxLength: int) : string {
        if (name.length <= maxLength) {
            return name
        }
        const keep = Math.floor((maxLength - 1) / 2)
        return name.substring(0, keep) + "…" + name.substring(name.length - keep)
    }

    function showIfIdle() : void {
        if (root.m_mpv.currentUrl.toString() === "") {
            Models.recentFilesModel.getItems()
            root.open()
        }
    }

    Connections {
        target: root.m_mpv
        function onCurrentUrlChanged() {
            if (root.m_mpv.currentUrl.toString() !== "") {
                root.close()
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            spacing: Kirigami.Units.largeSpacing
            Kirigami.Icon {
                source: "io.github.python2121.FloatFrame"
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Kirigami.Units.iconSizes.large
            }
            Kirigami.Heading {
                text: KI18n.i18nc("@title", "Float Frame")
                level: 2
                Layout.fillWidth: true
            }
            ToolButton {
                icon.name: "window-close"
                focusPolicy: Qt.NoFocus
                ToolTip.text: KI18n.i18nc("@info:tooltip", "Close")
                ToolTip.visible: hovered
                onClicked: root.close()
            }
        }

        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Button {
                action: HarunaApp.actions.openFileAction
                highlighted: true
                Layout.fillWidth: true
            }
            Button {
                action: HarunaApp.actions.openUrlAction
                Layout.fillWidth: true
            }
        }

        Label {
            text: KI18n.i18nc("@title", "Recent")
            opacity: 0.7
            visible: recentRepeater.count > 0
            Layout.topMargin: Kirigami.Units.smallSpacing
        }

        Repeater {
            id: recentRepeater
            model: Models.recentFilesModel
            delegate: Button {
                id: recentDelegate

                required property int index
                required property string url
                required property string filename
                required property string toolTipText

                visible: recentDelegate.index < root.maxRecent
                flat: true
                icon.name: "video-x-generic"
                text: root.shortened(recentDelegate.filename, 44)
                display: AbstractButton.TextBesideIcon
                Layout.fillWidth: true
                ToolTip.text: recentDelegate.toolTipText
                ToolTip.visible: hovered && recentDelegate.toolTipText !== ""
                ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: {
                    const mainWindow = Window.window as Main
                    mainWindow.openFile(recentDelegate.url, RecentFilesModel.OpenedFrom.Other)
                }
            }
        }
    }
}
