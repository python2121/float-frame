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
Item {
    id: root

    required property Window targetWindow
    property int edgeSize: 8
    property int cornerSize: 16

    component Handle: MouseArea {
        required property int edges

        acceptedButtons: Qt.LeftButton
        onPressed: SystemUtils.startSystemResize(root.targetWindow, edges)
    }

    // edges
    Handle {
        edges: Qt.LeftEdge
        cursorShape: Qt.SizeHorCursor
        width: root.edgeSize
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: root.cornerSize; bottomMargin: root.cornerSize }
    }
    Handle {
        edges: Qt.RightEdge
        cursorShape: Qt.SizeHorCursor
        width: root.edgeSize
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: root.cornerSize; bottomMargin: root.cornerSize }
    }
    Handle {
        edges: Qt.TopEdge
        cursorShape: Qt.SizeVerCursor
        height: root.edgeSize
        anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: root.cornerSize; rightMargin: root.cornerSize }
    }
    Handle {
        edges: Qt.BottomEdge
        cursorShape: Qt.SizeVerCursor
        height: root.edgeSize
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: root.cornerSize; rightMargin: root.cornerSize }
    }

    // corners
    Handle {
        edges: Qt.LeftEdge | Qt.TopEdge
        cursorShape: Qt.SizeFDiagCursor
        width: root.cornerSize; height: root.cornerSize
        anchors { left: parent.left; top: parent.top }
    }
    Handle {
        edges: Qt.RightEdge | Qt.TopEdge
        cursorShape: Qt.SizeBDiagCursor
        width: root.cornerSize; height: root.cornerSize
        anchors { right: parent.right; top: parent.top }
    }
    Handle {
        edges: Qt.LeftEdge | Qt.BottomEdge
        cursorShape: Qt.SizeBDiagCursor
        width: root.cornerSize; height: root.cornerSize
        anchors { left: parent.left; bottom: parent.bottom }
    }
    Handle {
        edges: Qt.RightEdge | Qt.BottomEdge
        cursorShape: Qt.SizeFDiagCursor
        width: root.cornerSize; height: root.cornerSize
        anchors { right: parent.right; bottom: parent.bottom }
    }
}
