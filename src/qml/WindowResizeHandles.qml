/*
 * SPDX-FileCopyrightText: 2026 Float Frame contributors
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick

import org.kde.haruna.utilities

// Invisible grab zones along the edges and corners of a frameless window.
// Pressing one asks the compositor to start an interactive resize, so the
// window behaves exactly like one with a frame (KWin does the resizing).
//
// Fill the whole surface with this. With `outerSize` set (Main.qml's
// frameMargin band, which the compositor treats as outside the window) the
// zones start beyond the visible edge, like a decorated window's, and reach
// only a few pixels inside it. Without a band they have to live entirely
// inside the window, so they reach further in.
Item {
    id: root

    required property Window targetWindow
    property int outerSize: 0
    property int edgeSize: outerSize > 0 ? 4 : 8
    property int cornerSize: outerSize > 0 ? 10 : 16

    // total reach of a zone, band included
    readonly property int edgeReach: outerSize + edgeSize
    readonly property int cornerReach: outerSize + cornerSize

    component Handle: MouseArea {
        id: handle

        required property int edges

        acceptedButtons: Qt.LeftButton
        onPressed: SystemUtils.startSystemResize(root.targetWindow, handle.edges, handle)
    }

    // edges
    Handle {
        edges: Qt.LeftEdge
        cursorShape: Qt.SizeHorCursor
        width: root.edgeReach
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: root.cornerReach; bottomMargin: root.cornerReach }
    }
    Handle {
        edges: Qt.RightEdge
        cursorShape: Qt.SizeHorCursor
        width: root.edgeReach
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: root.cornerReach; bottomMargin: root.cornerReach }
    }
    Handle {
        edges: Qt.TopEdge
        cursorShape: Qt.SizeVerCursor
        height: root.edgeReach
        anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: root.cornerReach; rightMargin: root.cornerReach }
    }
    Handle {
        edges: Qt.BottomEdge
        cursorShape: Qt.SizeVerCursor
        height: root.edgeReach
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: root.cornerReach; rightMargin: root.cornerReach }
    }

    // corners
    Handle {
        edges: Qt.LeftEdge | Qt.TopEdge
        cursorShape: Qt.SizeFDiagCursor
        width: root.cornerReach; height: root.cornerReach
        anchors { left: parent.left; top: parent.top }
    }
    Handle {
        edges: Qt.RightEdge | Qt.TopEdge
        cursorShape: Qt.SizeBDiagCursor
        width: root.cornerReach; height: root.cornerReach
        anchors { right: parent.right; top: parent.top }
    }
    Handle {
        edges: Qt.LeftEdge | Qt.BottomEdge
        cursorShape: Qt.SizeBDiagCursor
        width: root.cornerReach; height: root.cornerReach
        anchors { left: parent.left; bottom: parent.bottom }
    }
    Handle {
        edges: Qt.RightEdge | Qt.BottomEdge
        cursorShape: Qt.SizeFDiagCursor
        width: root.cornerReach; height: root.cornerReach
        anchors { right: parent.right; bottom: parent.bottom }
    }
}
