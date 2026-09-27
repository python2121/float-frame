// Spike: can a Qt 6 Wayland window toggle Qt.FramelessWindowHint at runtime,
// and do startSystemMove()/startSystemResize() work for a frameless window?
//   flatpak run --command=qml org.kde.Sdk//6.11 docs/spikes/frameless.qml
// Left-drag moves, right/bottom edge drags resize, click "toggle" flips the frame.
import QtQuick
import QtQuick.Controls

Window {
    id: win
    width: 640; height: 360; visible: true
    color: "black"
    title: "frameless spike"
    property bool frameless: false
    flags: frameless ? (Qt.Window | Qt.FramelessWindowHint) : Qt.Window

    onFlagsChanged: console.log("flags", flags, "visible", visible, "geom", x, y, width, height, "visibility", visibility)
    onXChanged: console.log("x", x); onYChanged: console.log("y", y)
    onWidthChanged: console.log("w", width); onHeightChanged: console.log("h", height)
    onVisibilityChanged: console.log("visibility", visibility)

    Rectangle { anchors.fill: parent; color: win.frameless ? "#203040" : "#402030"
        Text { anchors.centerIn: parent; color: "white"; text: (win.frameless ? "FRAMELESS" : "framed") + "\ndrag to move, edges to resize" ; horizontalAlignment: Text.AlignHCenter }
    }
    // move: any drag on the body
    DragHandler {
        target: null
        onActiveChanged: if (active) win.startSystemMove()
    }
    // resize: 10px right edge and bottom edge
    MouseArea { width: 10; anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        cursorShape: Qt.SizeHorCursor; onPressed: win.startSystemResize(Qt.RightEdge) }
    MouseArea { height: 10; anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        cursorShape: Qt.SizeVerCursor; onPressed: win.startSystemResize(Qt.BottomEdge) }
    Button { text: "toggle"; anchors { top: parent.top; left: parent.left; margins: 8 }
        onClicked: win.frameless = !win.frameless }

    // automated part: toggle a few times and log; then exit
    Timer {
        interval: 1500; running: true; repeat: true
        property int n: 0
        onTriggered: {
            n++
            if (n <= 4) {
                console.log("--- auto toggle", n)
                win.frameless = !win.frameless
            } else if (n === 8 && Qt.application.arguments.indexOf("--auto") >= 0) {
                Qt.quit()
            }
        }
    }
    Component.onCompleted: console.log("platform", Qt.platform.pluginName, "started", x, y, width, height)
}
