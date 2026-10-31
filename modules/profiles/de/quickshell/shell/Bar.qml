import QtQuick 6.0
import QtQuick.Layouts 6.0
import QtQuick.Controls 6.0
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Quickshell.Wayland._IdleInhibitor

Item {
    id: root

    property var screen: null
    property var panelWindow: null

    implicitHeight: 46

    IdleInhibitor {
        window: root.panelWindow
        enabled: root.panelWindow !== null && ShellState.idleInhibited && ShellState.isPreferredScreen(root.screen)
    }

    function networkTooltip() {
        if (!ShellState.networkConnected) return "Network offline"
        var lines = [ShellState.networkName, ShellState.networkLabel]
        if (ShellState.networkInterface.length > 0) lines.push("Interface: " + ShellState.networkInterface)
        if (ShellState.networkSignal > 0) lines.push("Signal: " + ShellState.networkSignal + "%")
        if (ShellState.networkAddress.length > 0) lines.push("Address: " + ShellState.networkAddress)
        if (ShellState.networkGateway.length > 0) lines.push("Gateway: " + ShellState.networkGateway)
        return lines.join("\n")
    }

    function audioTooltip() {
        if (ShellState.audioShowSource) {
            return ShellState.sourceName + "\n" + (ShellState.sourceMuted ? "Muted" : Math.round(ShellState.sourceVolume * 100) + "%")
        }
        return ShellState.sinkName + "\n" + (ShellState.sinkMuted ? "Muted" : Math.round(ShellState.sinkVolume * 100) + "%")
    }

    function batteryTooltip() {
        var lines = [ShellState.batteryStatus, ShellState.batteryLevel + "%"]
        var time = ShellState.batteryTimeLabel()
        if (time.length > 0) {
            var suffix = ShellState.batteryStatus === "Charging" ? " until full" : (ShellState.batteryStatus === "Discharging" ? " remaining" : "")
            lines.push(time + suffix)
        }
        return lines.join("\n")
    }

    function memoryTooltip() {
        function gib(value) { return (Number(value || 0) / 1024).toFixed(1) + " GiB" }
        return "Memory: " + gib(ShellState.memoryUsedMiB) + " / " + gib(ShellState.memoryTotalMiB) +
            "\nSwap: " + gib(ShellState.swapUsedMiB) + " / " + gib(ShellState.swapTotalMiB)
    }

    function metricAccent(value, normal) {
        var severity = ShellState.metricSeverity(value)
        if (severity === "high") return Theme.danger
        if (severity === "warning") return Theme.warning
        return normal
    }

    function bluetoothTooltip() {
        var lines = [ShellState.bluetoothControllerName || "Bluetooth unavailable"]
        if (ShellState.bluetoothControllerAddress.length > 0) lines.push(ShellState.bluetoothControllerAddress)
        if (ShellState.bluetoothDevices.length === 0) {
            lines.push("No connected devices")
        } else {
            for (var i = 0; i < ShellState.bluetoothDevices.length; i++) {
                var device = ShellState.bluetoothDevices[i]
                var line = device.name
                if (device.address) line += " · " + device.address
                if (device.battery >= 0) line += " · " + Math.round(device.battery) + "%"
                lines.push(line)
            }
        }
        return lines.join("\n")
    }

    function showTrayMenu(item, area) {
        if (!item || !item.hasMenu || !root.panelWindow) return
        var point = area.mapToItem(root, area.width / 2, area.height)
        item.display(root.panelWindow, Math.round(point.x), Math.round(point.y))
    }

    function trayIconSource(item) {
        if (!item) return ""

        var icon = String(item.icon || "")
        if (icon.length > 0) {
            // StatusNotifierItem normally supplies a file/data URL, but some
            // clients send a theme icon name instead.
            if (icon.indexOf(":") >= 0 || icon.indexOf("/") >= 0) return icon
            var themeIcon = Quickshell.iconPath(icon, true)
            if (themeIcon.length > 0) return themeIcon
            return ""
        }

        return ""
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        radius: 12
        color: Theme.background
        border.width: 0
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 4

        WorkspaceStrip {
            screen: root.screen
            Layout.preferredWidth: Math.min(260, Math.max(70, implicitWidth))
            Layout.minimumWidth: 70
            Layout.maximumWidth: 260
        }

        Text {
            text: ShellState.focusedTitle
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.bodyFontSize
            elide: Text.ElideMiddle
            Layout.fillWidth: true
            Layout.minimumWidth: 48
            Layout.maximumWidth: 320
            verticalAlignment: Text.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            spacing: 3

            CavaVisualizer {
                active: ShellState.audioReady && ShellState.isPreferredScreen(root.screen) && !ShellState.onBattery
                Layout.preferredWidth: 72
                Layout.preferredHeight: 22
            }

            Text {
                visible: MediaState.available
                text: MediaState.artist.length > 0 ? MediaState.artist + " · " + MediaState.title : MediaState.title
                color: MediaState.playing ? Theme.text : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.maximumWidth: 150
                verticalAlignment: Text.AlignVCenter
            }
        }

        StatusPill {
            icon: "󰻠"
            value: ShellState.cpuUsage + "%"
            tooltip: "CPU: " + ShellState.cpuUsage + "% (" + ShellState.metricSeverity(ShellState.cpuUsage) + ")" +
                (ShellState.cpuFrequencyMHz > 0 ? "\nFrequency: " + ShellState.cpuFrequencyMHz + " MHz" : "") +
                (ShellState.cpuCores > 0 ? "\nCores: " + ShellState.cpuCores : "") +
                "\nLoad: " + ShellState.loadAverage.toFixed(2)
            accent: root.metricAccent(ShellState.cpuUsage, Theme.muted)
            highlighted: ShellState.metricSeverity(ShellState.cpuUsage) !== "normal"
            onClicked: ShellState.togglePopup("system", root.screen)
            onRightClicked: ShellState.togglePopup("system", root.screen)
        }

        StatusPill {
            icon: ""
            value: ShellState.memoryUsage + "%"
            tooltip: root.memoryTooltip()
            accent: root.metricAccent(ShellState.memoryUsage, Theme.muted)
            highlighted: ShellState.metricSeverity(ShellState.memoryUsage) !== "normal"
            onClicked: ShellState.togglePopup("system", root.screen)
            onRightClicked: ShellState.togglePopup("system", root.screen)
        }

        StatusPill {
            visible: ShellState.temperature > 0
            icon: "󰔏"
            value: ShellState.temperature + "°C"
            tooltip: "Temperature"
            accent: ShellState.temperature >= 80 ? Theme.danger : Theme.muted
            highlighted: ShellState.temperature >= 80
            onClicked: ShellState.togglePopup("system", root.screen)
            onRightClicked: ShellState.togglePopup("system", root.screen)
        }

        StatusPill {
            icon: !ShellState.networkConnected ? "󰤭" : (ShellState.networkType === "ethernet" ? "" : "󰤨")
            value: ShellState.networkShowDetails
                ? ((ShellState.networkInterface || "network") + (ShellState.networkAddress ? ": " + ShellState.networkAddress : ""))
                : (!ShellState.networkConnected ? "Offline" : (ShellState.networkType === "wifi" ? ShellState.networkSignal + "%" : "LAN"))
            tooltip: root.networkTooltip()
            accent: !ShellState.networkConnected ? Theme.danger : Theme.muted
            highlighted: !ShellState.networkConnected
            onClicked: ShellState.togglePopup("network", root.screen)
            onRightClicked: ShellState.run([Commands.nmEditor])
            onMiddleClicked: ShellState.toggleNetworkFormat()
        }

        StatusPill {
            icon: ShellState.bluetoothPowered ? "󰂯" : "󰂲"
            value: ShellState.bluetoothDisplayLabel()
            tooltip: root.bluetoothTooltip()
            accent: ShellState.bluetoothPowered ? Theme.muted : Theme.subtle
            onClicked: ShellState.togglePopup("bluetooth", root.screen)
            onRightClicked: ShellState.run([Commands.blueman])
            onMiddleClicked: ShellState.toggleBluetoothFormat()
        }

        StatusPill {
            icon: ShellState.audioShowSource ? (ShellState.sourceMuted ? "󰍭" : "󰍬") : (ShellState.sinkMuted ? "󰖁" : "󰕾")
            value: ShellState.audioShowSource
                ? (ShellState.sourceReady ? Math.round(ShellState.sourceVolume * 100) + "%" : "Input")
                : (ShellState.audioReady ? Math.round(ShellState.sinkVolume * 100) + "%" : "Audio")
            tooltip: root.audioTooltip()
            accent: (ShellState.audioShowSource ? ShellState.sourceMuted : ShellState.sinkMuted) ? Theme.danger : Theme.muted
            highlighted: ShellState.audioShowSource ? ShellState.sourceMuted : ShellState.sinkMuted
            onClicked: ShellState.togglePopup("audio", root.screen)
            onRightClicked: ShellState.run([Commands.pavucontrol])
            onMiddleClicked: ShellState.toggleAudioDisplay()
            onScrolled: direction => ShellState.adjustVolume(direction)
        }

        StatusPill {
            visible: Commands.fanEnabled
            icon: "󰈐"
            value: ""
            tooltip: FanState.summary
            accent: FanState.accentColor
            selected: UiState.popupOpen && UiState.popupPage === "fan"
            highlighted: FanState.errorMessage.length > 0 || FanState.controlMode === "degraded"
            onClicked: ShellState.togglePopup("fan", root.screen)
        }

        StatusPill {
            visible: Commands.rgbEnabled
            icon: RgbState.power ? "󰏘" : "󰌶"
            value: ""
            tooltip: RgbState.summary
            accent: RgbState.power ? RgbState.accentColor : Theme.subtle
            selected: UiState.popupOpen && UiState.popupPage === "rgb"
            highlighted: RgbState.errorMessage.length > 0
            onClicked: ShellState.togglePopup("rgb", root.screen)
            onMiddleClicked: RgbState.togglePower()
            onScrolled: direction => RgbState.adjustBrightness(direction)
        }

        StatusPill {
            visible: ShellState.brightness > 0
            icon: ShellState.brightnessIcon()
            value: ShellState.brightness + "%"
            tooltip: "Brightness: " + ShellState.brightness + "%"
            accent: Theme.muted
            onClicked: ShellState.togglePopup("overview", root.screen)
            onScrolled: direction => ShellState.adjustBrightness(direction)
        }

        StatusPill {
            visible: ShellState.screenShareActive
            icon: "󰖟"
            value: "Share"
            tooltip: ShellState.privacyTooltip("screen")
            accent: Theme.warning
            highlighted: true
            onClicked: ShellState.togglePopup("overview", root.screen)
        }

        StatusPill {
            visible: ShellState.audioInUse
            icon: "󰍬"
            value: "Mic"
            tooltip: ShellState.privacyTooltip("audio")
            accent: Theme.warning
            highlighted: true
            onClicked: ShellState.togglePopup("overview", root.screen)
        }

        StatusPill {
            icon: ShellState.idleInhibited ? "" : ""
            value: ShellState.idleInhibited ? "On" : ""
            tooltip: ShellState.idleInhibited ? "Idle inhibition enabled" : "Idle inhibition disabled"
            accent: ShellState.idleInhibited ? Theme.warning : Theme.subtle
            selected: ShellState.idleInhibited
            onClicked: UiState.idleInhibited = !UiState.idleInhibited
        }

        StatusPill {
            visible: ShellState.isBedtime()
            icon: "󰋣"
            value: "!"
            tooltip: "Bedtime window: 22:00-06:00"
            accent: Theme.warning
            selected: true
            blinking: true
            onClicked: ShellState.togglePopup("calendar", root.screen)
        }

        IconButton {
            icon: "󰸉"
            tooltip: "Next wallpaper"
            iconColor: Theme.muted
            onClicked: ShellState.run([Commands.wpaperctl, "next-wallpaper"])
        }

        StatusPill {
            visible: ShellState.batteryStatus !== "Unknown"
            icon: ShellState.batteryIcon()
            value: ShellState.batteryDisplayLabel()
            tooltip: root.batteryTooltip()
            accent: ShellState.batterySeverity() === "critical" ? Theme.danger
                : (ShellState.batterySeverity() === "warning" ? Theme.warning : Theme.muted)
            highlighted: ShellState.batterySeverity() !== "normal"
            blinking: ShellState.batterySeverity() === "critical" && ShellState.onBattery
            onClicked: ShellState.togglePopup("overview", root.screen)
            onMiddleClicked: ShellState.toggleBatteryFormat()
        }

        StatusPill {
            icon: "󰄬"
            visible: Commands.taskEnabled
            value: TaskState.ready ? String(TaskState.totalCount) : "..."
            tooltip: TaskState.errorMessage.length > 0
                ? TaskState.errorMessage
                : TaskState.totalCount + " pending" + (TaskState.overdueCount > 0 ? "\n" + TaskState.overdueCount + " overdue" : "")
            accent: TaskState.overdueCount > 0 ? Theme.danger : Theme.muted
            highlighted: TaskState.overdueCount > 0
            onClicked: ShellState.togglePopup("tasks", root.screen)
            onRightClicked: if (Commands.taskEnabled) ShellState.run([Commands.taskTerminal])
        }

        StatusPill {
            icon: "󰔛"
            value: ShellState.clockAlternate ? Qt.formatDate(ShellState.now, "yyyy-MM-dd") : Qt.formatTime(ShellState.now, "HH:mm")
            tooltip: Qt.formatDate(ShellState.now, "dddd, MMMM d, yyyy")
            accent: Theme.muted
            onClicked: ShellState.togglePopup("calendar", root.screen)
            onRightClicked: if (Commands.taskEnabled) ShellState.run([Commands.taskTerminal])
            onMiddleClicked: ShellState.toggleClockFormat()
        }

        IconButton {
            icon: "󰐥"
            tooltip: "Power"
            iconColor: Theme.muted
            onClicked: ShellState.togglePopup("power", root.screen)
        }

        RowLayout {
            visible: ShellState.isPreferredScreen(root.screen)
            spacing: 2

            Repeater {
                model: SystemTray.items

                delegate: Item {
                    id: trayItem
                    required property var modelData
                    readonly property bool needsAttention: modelData.status === Status.NeedsAttention
                    readonly property string iconSource: root.trayIconSource(modelData)
                    implicitWidth: modelData.status === Status.Passive ? 0 : 26
                    implicitHeight: 28
                    activeFocusOnTab: modelData.status !== Status.Passive
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.tooltipTitle || "System tray item"

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                            event.accepted = true
                            trayTooltip.dismiss()
                            if (modelData.onlyMenu && modelData.hasMenu) root.showTrayMenu(modelData, trayItem)
                            else modelData.activate()
                        }
                    }
                    Accessible.onPressAction: {
                        trayTooltip.dismiss()
                        if (modelData.onlyMenu && modelData.hasMenu) root.showTrayMenu(modelData, trayItem)
                        else modelData.activate()
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.smallRadius
                        color: needsAttention ? Theme.tint(Theme.danger, 0.16) : ((trayMouse.containsMouse || trayItem.activeFocus) ? Theme.surface : "transparent")
                        border.width: trayItem.activeFocus ? 1 : 0
                        border.color: Theme.accent
                    }

                    IconImage {
                        id: trayIcon
                        visible: trayItem.iconSource.length > 0
                        anchors.centerIn: parent
                        implicitSize: 18
                        source: trayItem.iconSource
                        mipmap: true
                    }

                    Text {
                        visible: trayItem.iconSource.length === 0
                        anchors.centerIn: parent
                        text: "•"
                        color: needsAttention ? Theme.danger : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                    }

                    MouseArea {
                        id: trayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            trayTooltip.dismiss()
                            trayItem.forceActiveFocus(Qt.MouseFocusReason)
                        }
                        onClicked: event => {
                            if (event.button === Qt.RightButton) {
                                if (modelData.hasMenu) root.showTrayMenu(modelData, trayMouse)
                                else modelData.secondaryActivate()
                            } else if (event.button === Qt.MiddleButton) {
                                modelData.secondaryActivate()
                            } else if (modelData.onlyMenu && modelData.hasMenu) {
                                root.showTrayMenu(modelData, trayMouse)
                            } else {
                                modelData.activate()
                            }
                        }
                        onWheel: event => {
                            var delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                            if (delta !== 0) modelData.scroll(delta, event.angleDelta.y === 0)
                            event.accepted = true
                        }
                    }

                    HoverTooltip {
                        id: trayTooltip
                        targetItem: trayItem
                        hovered: trayMouse.containsMouse
                        focused: trayItem.activeFocus
                        delay: 450
                        text: modelData.tooltipDescription.length > 0
                            ? modelData.tooltipTitle + "\n" + modelData.tooltipDescription
                            : modelData.tooltipTitle
                    }
                }
            }
        }
    }
}
