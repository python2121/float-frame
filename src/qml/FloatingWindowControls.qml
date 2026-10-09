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
import org.kde.haruna.settings
import org.kde.haruna.utilities

// Chromeless mode: the title bar's essentials as a translucent bar that
// appears on mouse movement and fades like the floating footer. Buttons
// drive the real window (minimize, maximize/restore, close); dragging the bar
// moves the window, double-clicking it toggles maximize, as in KDE.
Item {
    id: root

    required property MpvVideo m_mpv

    property bool isSmallSize: width < 600
    property int buttonSize: isSmallSize ? Kirigami.Units.iconSizes.small : Kirigami.Units.iconSizes.smallMedium
    property string barState: "hidden"

    readonly property Window targetWindow: Window.window
    // the window is being moved or resized: stay up, count down once it ends
    readonly property bool grabActive: (targetWindow as Main)?.windowGrabActive === true
    onGrabActiveChanged: {
        if (!shouldShow) {
            return
        }
        hideTimer.stop()
        leaveHideTimer.stop()
        if (grabActive) {
            barState = "visible"
        } else {
            hideTimer.restart()
        }
    }
    readonly property bool shouldShow: (targetWindow as Main)?.chromeless === true
                                       && targetWindow.visibility !== Window.FullScreen

    implicitHeight: bar.height
    visible: shouldShow
    onShouldShowChanged: {
        if (!shouldShow) {
            barState = "hidden"
        }
    }

    // Same rules as the floating footer (Footer.floatingState), top edge
    // instead of bottom: every mouse movement shows it and it hides 1.3 s later
    // unless the pointer is near it; in "edge" trigger mode it only shows while
    // the pointer is near the top edge.
    function show() : void {
        if (root.grabActive) {
            return
        }
        if (GeneralSettings.floatingFooterTrigger === "EveryMouseMovement") {
            hideTimer.stop()
            root.barState = "visible"
            if (root.m_mpv.mouseY > bar.height * 2) {
                hideTimer.restart()
            }
        } else {
            if (root.m_mpv.mouseY < bar.height * 2) {
                if ((root.targetWindow as Main).containsMouse) {
                    hideTimer.stop()
                    root.barState = "visible"
                }
            } else {
                hideTimer.restart()
            }
        }
    }

    Connections {
        target: root.m_mpv
        function onMousePositionChanged(x, y) {
            if (root.shouldShow) {
                Qt.callLater(root.show)
            }
        }
    }

    Connections {
        target: HarunaApp
        function onQmlApplicationMouseLeave() {
            if (root.grabActive) {
                return
            }
            hideTimer.stop()
            leaveHideTimer.restart()
        }
        function onQmlApplicationMouseEnter() {
            leaveHideTimer.stop()
        }
    }

    // pointer left the window: hide 2.6 s later regardless of the hover state
    Timer {
        id: leaveHideTimer
        interval: 2600
        onTriggered: root.barState = "hidden"
    }

    Timer {
        id: hideTimer
        interval: 1300
        onTriggered: {
            // like the footer: stay while hovered, the next mouse move re-arms
            if (bar.hovered) {
                return
            }
            root.barState = "hidden"
        }
    }

    ToolBar {
        id: bar

        // a title-bar strip: full width, flush with the top edge
        x: 0
        width: root.width

        padding: Kirigami.Units.smallSpacing
        position: ToolBar.Header
        hoverEnabled: true
        state: root.barState
        background: Rectangle {
            color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.85)
        }

        // title-bar gestures: drag to move, double-click to maximize/restore
        DragHandler {
            target: null
            onActiveChanged: {
                if (active) {
                    (root.targetWindow as Main).startWindowMove(null)
                }
            }
        }
        TapHandler {
            onDoubleTapped: root.toggleMaximized()
        }

        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "io.github.python2121.FloatFrame"
                Layout.preferredWidth: root.buttonSize
                Layout.preferredHeight: root.buttonSize
                Layout.leftMargin: Kirigami.Units.smallSpacing
            }
            Label {
                text: root.targetWindow.title
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }
            ToolButton {
                icon.name: "window-minimize"
                icon.width: root.buttonSize
                icon.height: root.buttonSize
                focusPolicy: Qt.NoFocus
                ToolTip.text: KI18n.i18nc("@info:tooltip", "Minimize")
                ToolTip.visible: hovered
                onClicked: root.targetWindow.showMinimized()
            }
            ToolButton {
                icon.name: root.targetWindow.visibility === Window.Maximized ? "window-restore" : "window-maximize"
                icon.width: root.buttonSize
                icon.height: root.buttonSize
                focusPolicy: Qt.NoFocus
                ToolTip.text: root.targetWindow.visibility === Window.Maximized
                              ? KI18n.i18nc("@info:tooltip", "Restore")
                              : KI18n.i18nc("@info:tooltip", "Maximize")
                ToolTip.visible: hovered
                onClicked: root.toggleMaximized()
            }
            ToolButton {
                icon.name: "window-close"
                icon.width: root.buttonSize
                icon.height: root.buttonSize
                focusPolicy: Qt.NoFocus
                ToolTip.text: KI18n.i18nc("@info:tooltip", "Close")
                ToolTip.visible: hovered
                onClicked: root.targetWindow.close()
            }
        }

        states: [
            State {
                name: "hidden"
                PropertyChanges {
                    bar.y: -bar.height
                    bar.visible: false
                }
            },
            State {
                name: "visible"
                PropertyChanges {
                    bar.y: 0
                    bar.visible: true
                }
            }
        ]

        transitions: [
            Transition {
                from: "visible"
                to: "hidden"
                SequentialAnimation {
                    NumberAnimation { target: bar; property: "y"; duration: Kirigami.Units.shortDuration; easing.type: Easing.Linear }
                    PropertyAction { target: bar; property: "visible"; value: false }
                }
            },
            Transition {
                from: "hidden"
                to: "visible"
                SequentialAnimation {
                    PropertyAction { target: bar; property: "visible"; value: true }
                    NumberAnimation { target: bar; property: "y"; duration: Kirigami.Units.shortDuration; easing.type: Easing.Linear }
                }
            }
        ]
    }

    function toggleMaximized() : void {
        if (root.targetWindow.visibility === Window.Maximized) {
            root.targetWindow.showNormal()
        } else {
            root.targetWindow.showMaximized()
        }
    }
}
