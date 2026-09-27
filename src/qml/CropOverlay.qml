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

// Crop-to-content selection: dims everything but a rectangle the user drags
// over the paused picture. Enter / double-click applies, Esc cancels. The
// rectangle is mapped to source pixels for mpv's video-crop property.
Item {
    id: root

    required property MpvVideo m_mpv

    property bool active: false
    // selection and the picture rectangle, in item coordinates
    property rect selection: Qt.rect(0, 0, 0, 0)
    property rect videoRect: Qt.rect(0, 0, width, height)
    property var videoParams: null   // video-params, cached while selecting
    property int handleSize: 12
    property int minSize: 24

    signal applied(rect sourceRect)
    signal cancelled()

    anchors.fill: parent
    visible: active
    enabled: active
    focus: active

    function open() : void {
        root.videoParams = root.m_mpv.getProperty("video-params")
        updateVideoRect()
        selection = root.videoRect
        active = true
        forceActiveFocus()
        // a closing context menu may hand focus back to its previous item
        Qt.callLater(() => { if (root.active) root.forceActiveFocus() })
    }

    // the item resizes while selecting (window fit after lifting a crop, or the
    // user resizing): keep the selection at the same relative position
    function relayout() : void {
        if (!root.active) {
            return
        }
        const old = root.videoRect
        const sel = root.selection
        updateVideoRect()
        const vr = root.videoRect
        if (old.width <= 0 || old.height <= 0 || vr.width <= 0 || vr.height <= 0) {
            root.selection = vr
            return
        }
        const sx = vr.width / old.width
        const sy = vr.height / old.height
        root.selection = Qt.rect(vr.x + (sel.x - old.x) * sx, vr.y + (sel.y - old.y) * sy, sel.width * sx, sel.height * sy)
    }
    onWidthChanged: relayout()
    onHeightChanged: relayout()

    function cancel() : void {
        active = false
        root.cancelled()
    }

    function apply() : void {
        const src = toSourceRect()
        active = false
        if (src.width > 0 && src.height > 0) {
            root.applied(src)
        } else {
            root.cancelled()
        }
    }

    // where mpv draws the picture inside this item (letterbox margins removed)
    function updateVideoRect() : void {
        const osd = root.m_mpv.getProperty("osd-dimensions")
        if (!osd || !osd.w || !osd.h || root.width <= 0) {
            root.videoRect = Qt.rect(0, 0, root.width, root.height)
            return
        }
        const scale = osd.w / root.width   // render pixels per item pixel
        root.videoRect = Qt.rect(osd.ml / scale, osd.mt / scale,
                                 (osd.w - osd.ml - osd.mr) / scale,
                                 (osd.h - osd.mt - osd.mb) / scale)
    }

    // selection → source pixels (video-params/w,h; even numbers for chroma subsampling)
    function toSourceRect() : rect {
        const params = root.videoParams
        if (!params || !params.w || !params.h || root.videoRect.width <= 0 || root.videoRect.height <= 0) {
            return Qt.rect(0, 0, 0, 0)
        }
        const fx = params.w / root.videoRect.width
        const fy = params.h / root.videoRect.height
        let x = Math.round((root.selection.x - root.videoRect.x) * fx)
        let y = Math.round((root.selection.y - root.videoRect.y) * fy)
        let w = Math.round(root.selection.width * fx)
        let h = Math.round(root.selection.height * fy)
        x = Math.max(0, x - (x % 2))
        y = Math.max(0, y - (y % 2))
        w = Math.min(params.w - x, w - (w % 2))
        h = Math.min(params.h - y, h - (h % 2))
        // selecting (almost) everything means no crop
        if (w >= params.w - 2 && h >= params.h - 2) {
            return Qt.rect(0, 0, params.w, params.h)
        }
        return Qt.rect(x, y, w, h)
    }

    function clamp(v: real, lo: real, hi: real) : real {
        return Math.max(lo, Math.min(hi, v))
    }

    function normalized(x1: real, y1: real, x2: real, y2: real) : rect {
        const vr = root.videoRect
        x1 = clamp(x1, vr.x, vr.x + vr.width); x2 = clamp(x2, vr.x, vr.x + vr.width)
        y1 = clamp(y1, vr.y, vr.y + vr.height); y2 = clamp(y2, vr.y, vr.y + vr.height)
        return Qt.rect(Math.min(x1, x2), Math.min(y1, y2), Math.abs(x2 - x1), Math.abs(y2 - y1))
    }

    // which part of the selection is under (x, y): edges bitmask, "inside" or "outside"
    function regionAt(x: real, y: real) : var {
        const s = root.selection
        const hs = root.handleSize
        if (x < s.x - hs || x > s.x + s.width + hs || y < s.y - hs || y > s.y + s.height + hs) {
            return { edges: 0, inside: false }
        }
        let edges = 0
        const dl = Math.abs(x - s.x), dr = Math.abs(x - (s.x + s.width))
        const dt = Math.abs(y - s.y), db = Math.abs(y - (s.y + s.height))
        // narrow selections: only the nearer of two opposite edges
        if (dl <= hs && dl <= dr) edges |= Qt.LeftEdge
        else if (dr <= hs) edges |= Qt.RightEdge
        if (dt <= hs && dt <= db) edges |= Qt.TopEdge
        else if (db <= hs) edges |= Qt.BottomEdge
        return { edges: edges, inside: edges === 0 }
    }

    function cursorFor(region: var) : int {
        const e = region.edges
        if (e === (Qt.LeftEdge | Qt.TopEdge) || e === (Qt.RightEdge | Qt.BottomEdge)) return Qt.SizeFDiagCursor
        if (e === (Qt.RightEdge | Qt.TopEdge) || e === (Qt.LeftEdge | Qt.BottomEdge)) return Qt.SizeBDiagCursor
        if (e === Qt.LeftEdge || e === Qt.RightEdge) return Qt.SizeHorCursor
        if (e === Qt.TopEdge || e === Qt.BottomEdge) return Qt.SizeVerCursor
        return region.inside ? Qt.SizeAllCursor : Qt.CrossCursor
    }

    Keys.onShortcutOverride: function(event) {
        // keep Esc / Enter away from the application shortcuts while selecting
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true
        }
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            root.cancel()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.apply()
            event.accepted = true
        }
    }

    MouseArea {
        id: dragArea

        // drag state
        property string mode: ""          // "new", "move", "resize"
        property int resizeEdges: 0
        property point pressPos
        property rect pressSelection
        property var hoverRegion: ({ edges: 0, inside: false })

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: root.cursorFor(hoverRegion)

        onPressed: function(mouse) {
            const region = root.regionAt(mouse.x, mouse.y)
            pressPos = Qt.point(mouse.x, mouse.y)
            pressSelection = root.selection
            if (region.edges !== 0) {
                mode = "resize"
                resizeEdges = region.edges
            } else if (region.inside) {
                mode = "move"
            } else {
                mode = "new"
                root.selection = Qt.rect(mouse.x, mouse.y, 0, 0)
            }
        }

        onPositionChanged: function(mouse) {
            if (!pressed) {
                hoverRegion = root.regionAt(mouse.x, mouse.y)
                return
            }
            const dx = mouse.x - pressPos.x
            const dy = mouse.y - pressPos.y
            const s = pressSelection
            const vr = root.videoRect
            if (mode === "new") {
                root.selection = root.normalized(pressPos.x, pressPos.y, mouse.x, mouse.y)
            } else if (mode === "move") {
                const x = root.clamp(s.x + dx, vr.x, vr.x + vr.width - s.width)
                const y = root.clamp(s.y + dy, vr.y, vr.y + vr.height - s.height)
                root.selection = Qt.rect(x, y, s.width, s.height)
            } else if (mode === "resize") {
                let x1 = s.x, y1 = s.y, x2 = s.x + s.width, y2 = s.y + s.height
                if (resizeEdges & Qt.LeftEdge) x1 = Math.min(s.x + dx, x2 - root.minSize)
                if (resizeEdges & Qt.RightEdge) x2 = Math.max(s.x + s.width + dx, x1 + root.minSize)
                if (resizeEdges & Qt.TopEdge) y1 = Math.min(s.y + dy, y2 - root.minSize)
                if (resizeEdges & Qt.BottomEdge) y2 = Math.max(s.y + s.height + dy, y1 + root.minSize)
                root.selection = root.normalized(x1, y1, x2, y2)
            }
        }

        onReleased: function(mouse) {
            if (mode === "new" && (root.selection.width < root.minSize || root.selection.height < root.minSize)) {
                // a click, not a drag: keep the previous selection
                root.selection = pressSelection
            }
            mode = ""
            hoverRegion = root.regionAt(mouse.x, mouse.y)
        }

        onDoubleClicked: {
            // the second press of a double-click outside the box started a new
            // (empty) selection; apply the one the user actually had
            if (mode === "new") {
                root.selection = pressSelection
            }
            mode = ""
            root.apply()
        }
    }

    // dim everything outside the selection
    Rectangle { color: Qt.rgba(0, 0, 0, 0.6); x: 0; y: 0; width: parent.width; height: root.selection.y }
    Rectangle { color: Qt.rgba(0, 0, 0, 0.6); x: 0; y: root.selection.y + root.selection.height; width: parent.width; height: parent.height - y }
    Rectangle { color: Qt.rgba(0, 0, 0, 0.6); x: 0; y: root.selection.y; width: root.selection.x; height: root.selection.height }
    Rectangle { color: Qt.rgba(0, 0, 0, 0.6); x: root.selection.x + root.selection.width; y: root.selection.y; width: parent.width - x; height: root.selection.height }

    Rectangle {
        x: root.selection.x; y: root.selection.y
        width: root.selection.width; height: root.selection.height
        color: "transparent"
        border.color: Kirigami.Theme.highlightColor
        border.width: 2

        Repeater {
            model: [
                { ax: 0, ay: 0 }, { ax: 0.5, ay: 0 }, { ax: 1, ay: 0 },
                { ax: 0, ay: 0.5 }, { ax: 1, ay: 0.5 },
                { ax: 0, ay: 1 }, { ax: 0.5, ay: 1 }, { ax: 1, ay: 1 }
            ]
            delegate: Rectangle {
                required property var modelData
                width: root.handleSize; height: root.handleSize
                x: parent.width * modelData.ax - width / 2
                y: parent.height * modelData.ay - height / 2
                radius: 2
                color: Kirigami.Theme.highlightColor
                border.color: "white"
                border.width: 1
            }
        }
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Kirigami.Units.largeSpacing
        padding: Kirigami.Units.smallSpacing
        text: {
            if (!root.active) {
                return ""
            }
            const src = root.toSourceRect()
            return KI18n.i18nc("@info crop size in pixels", "%1 × %2 px", src.width, src.height)
        }
        color: "white"
        background: Rectangle { color: Qt.rgba(0, 0, 0, 0.7); radius: Kirigami.Units.cornerRadius }
    }

    ToolBar {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Kirigami.Units.largeSpacing * 2
        background: Rectangle { color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.85); radius: Kirigami.Units.cornerRadius }

        RowLayout {
            Label {
                text: KI18n.i18nc("@info", "Drag over the picture to keep only that part")
                Layout.rightMargin: Kirigami.Units.largeSpacing
            }
            ToolButton {
                focusPolicy: Qt.NoFocus   // Enter must apply the crop, not re-click a button
                text: KI18n.i18nc("@action:button", "Whole picture")
                icon.name: "zoom-fit-best"
                onClicked: root.selection = root.videoRect
            }
            ToolButton {
                focusPolicy: Qt.NoFocus   // Enter must apply the crop, not re-click a button
                text: KI18n.i18nc("@action:button", "Cancel")
                icon.name: "dialog-cancel"
                onClicked: root.cancel()
            }
            ToolButton {
                focusPolicy: Qt.NoFocus   // Enter must apply the crop, not re-click a button
                text: KI18n.i18nc("@action:button", "Crop")
                icon.name: "transform-crop"
                highlighted: true
                onClicked: root.apply()
            }
        }
    }
}
