pragma ComponentBehavior: Bound

import QtQuick 6.0
import Quickshell

Item {
    id: root

    property var screen: null
    property var outputName: screen && screen.name ? screen.name : ""
    property int cellWidth: 30
    property int cellHeight: 28

    implicitWidth: workspaces.implicitWidth
    implicitHeight: root.cellHeight
    clip: true

    Row {
        id: workspaces
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: root.cellHeight
        spacing: 2

        ScriptModel {
            id: workspaceModel
            values: ShellState.workspacesFor(root.outputName)
            objectProp: "id"
        }

        Repeater {
            model: workspaceModel

            delegate: Rectangle {
                id: workspaceCell
                required property var modelData
                readonly property string label: String(ShellState.workspaceLabel(modelData))
                readonly property bool numeric: /^[0-9]+$/.test(label)
                readonly property bool focused: Boolean(modelData.is_focused)
                readonly property bool activeOnOutput: Boolean(modelData.is_active)
                readonly property bool urgent: Boolean(modelData.is_urgent)
                readonly property bool empty: modelData.active_window_id === null || modelData.active_window_id === undefined
                property real pulseOpacity: 1

                width: numeric ? root.cellWidth : Math.min(132, Math.max(56, workspaceLabel.implicitWidth + 16))
                height: root.cellHeight
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Workspace " + label
                radius: Theme.smallRadius
                color: urgent
                    ? Theme.tint(Theme.danger, 0.16)
                    : (focused ? Theme.tint(Theme.accent, 0.13) : (mouse.containsMouse ? Theme.surface : "transparent"))
                border.width: 0
                border.color: Theme.accent

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        event.accepted = true
                        workspaceTooltip.dismiss()
                        ShellState.focusWorkspace(Number(modelData.idx || 1), modelData.output || root.outputName)
                    }
                }
                Accessible.onPressAction: {
                    workspaceTooltip.dismiss()
                    ShellState.focusWorkspace(Number(modelData.idx || 1), modelData.output || root.outputName)
                }

                Behavior on color {
                    ColorAnimation { duration: Theme.animationFast }
                }

                opacity: urgent ? pulseOpacity : 1

                SequentialAnimation on pulseOpacity {
                    running: urgent
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.62; duration: 650 }
                    NumberAnimation { to: 1.0; duration: 650 }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: urgent ? parent.width - 8 : (focused ? parent.width - 10 : (activeOnOutput ? 12 : 0))
                    height: 2
                    radius: 1
                    color: urgent ? Theme.danger : (focused ? Theme.accent : Theme.surfaceStrong)
                }

                Text {
                    id: workspaceLabel
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    text: label
                    color: urgent ? Theme.danger : (focused ? Theme.accent : (empty ? Theme.subtle : Theme.muted))
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.letterSpacing: 0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onPressed: workspaceTooltip.dismiss()
                    onClicked: ShellState.focusWorkspace(Number(modelData.idx || 1), modelData.output || root.outputName)
                }

                HoverTooltip {
                    id: workspaceTooltip
                    targetItem: workspaceCell
                    hovered: mouse.containsMouse
                    focused: workspaceCell.activeFocus
                    delay: 450
                    text: {
                        var state = workspaceCell.focused ? "focused" : (activeOnOutput ? "active" : "inactive")
                        if (empty) state += ", empty"
                        if (urgent) state += ", urgent"
                        return "Workspace " + label + " · " + state + (modelData.output ? "\n" + modelData.output : "")
                    }
                }
            }
        }
    }
}
