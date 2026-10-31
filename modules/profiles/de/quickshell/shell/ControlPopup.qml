pragma ComponentBehavior: Bound

import QtQuick 6.0
import QtQuick.Layouts 6.0
import QtQuick.Controls 6.3
import Quickshell

Rectangle {
    id: root

    property string page: "overview"
    property var screen: null
    property var parentWindow: null
    readonly property int metricIconWidth: 26
    readonly property int metricBarWidth: 120

    focus: true
    color: Theme.background
    radius: 14
    border.width: 0

    Keys.onEscapePressed: event => {
        event.accepted = true
        if (PowerState.confirmationPending) PowerState.cancelConfirmation()
        else ShellState.closePopup()
    }

    function pageIndex() {
        switch (root.page) {
        case "system": return 1
        case "audio": return 2
        case "network": return 3
        case "bluetooth": return 4
        case "fan": return 5
        case "rgb": return 6
        case "calendar": return 7
        case "tasks": return 8
        case "power": return 9
        default: return 0
        }
    }

    function pageTitle() {
        switch (root.page) {
        case "system": return "System"
        case "audio": return "Audio"
        case "network": return "Network"
        case "bluetooth": return "Bluetooth"
        case "fan": return "Fan control"
        case "rgb": return "RGB lighting"
        case "calendar": return ShellState.calendarTitle
        case "tasks": return "Tasks"
        case "power": return "Power"
        default: return "Control center"
        }
    }

    function metricAccent(value, normal) {
        var severity = ShellState.metricSeverity(value)
        if (severity === "high") return Theme.danger
        if (severity === "warning") return Theme.warning
        return normal
    }

    function metricSurface(value, normal) {
        return Theme.tint(metricAccent(value, normal), 0.10)
    }

    function gib(value) {
        return (Number(value || 0) / 1024).toFixed(1) + " GiB"
    }

    function memoryTooltip() {
        return "Memory\n" + gib(ShellState.memoryUsedMiB) + " / " + gib(ShellState.memoryTotalMiB) +
            " (" + ShellState.memoryUsage + "%)\nSwap\n" + gib(ShellState.swapUsedMiB) + " / " + gib(ShellState.swapTotalMiB)
    }

    function batteryDetails() {
        var lines = [ShellState.batteryLevel + "%", ShellState.batteryStatus]
        var time = ShellState.batteryTimeLabel()
        if (time.length > 0) {
            var suffix = ShellState.batteryStatus === "Charging" ? " until full" : (ShellState.batteryStatus === "Discharging" ? " remaining" : "")
            lines.push(time + suffix)
        }
        return lines.join("\n")
    }

    function cpuDetails() {
        var details = []
        if (ShellState.cpuFrequencyMHz > 0) details.push(ShellState.cpuFrequencyMHz + " MHz")
        if (ShellState.cpuCores > 0) details.push(ShellState.cpuCores + " cores")
        details.push("load " + ShellState.loadAverage.toFixed(2))
        return details.join(" · ")
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 1

                Text {
                    text: root.pageTitle()
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }

                Text {
                    visible: root.page !== "calendar"
                    text: root.page === "tasks" ? TaskState.headerSummary
                        : (root.page === "fan" ? FanState.summary
                        : (root.page === "rgb" ? RgbState.summary : ShellState.focusedTitle))
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }

            IconButton {
                icon: "×"
                tooltip: "Close"
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                onClicked: ShellState.closePopup()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 3

            IconButton { icon: "⌂"; tooltip: "Overview"; selected: root.page === "overview"; onClicked: UiState.popupPage = "overview" }
            IconButton { icon: "󰒓"; tooltip: "System"; selected: root.page === "system"; onClicked: UiState.popupPage = "system" }
            IconButton { icon: "󰕾"; tooltip: "Audio"; selected: root.page === "audio"; onClicked: UiState.popupPage = "audio" }
            IconButton { icon: "󰤨"; tooltip: "Network"; selected: root.page === "network"; onClicked: UiState.popupPage = "network" }
            IconButton { icon: "󰂯"; tooltip: "Bluetooth"; selected: root.page === "bluetooth"; onClicked: UiState.popupPage = "bluetooth" }
            IconButton { visible: Commands.fanEnabled; icon: "󰈐"; tooltip: "Fan control"; selected: root.page === "fan"; onClicked: UiState.popupPage = "fan" }
            IconButton { visible: Commands.rgbEnabled; icon: "󰏘"; tooltip: "RGB lighting"; selected: root.page === "rgb"; onClicked: UiState.popupPage = "rgb" }
            IconButton { icon: "󰃭"; tooltip: "Calendar"; selected: root.page === "calendar"; onClicked: UiState.popupPage = "calendar" }
            IconButton { visible: Commands.taskEnabled; icon: "󰄬"; tooltip: "Tasks"; selected: root.page === "tasks"; onClicked: UiState.popupPage = "tasks" }
            IconButton { icon: "󰐥"; tooltip: "Power"; selected: root.page === "power"; onClicked: UiState.popupPage = "power" }
        }

        StackLayout {
            id: pages
            currentIndex: root.pageIndex()
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: 76
                        spacing: 8

                        Rectangle {
                            id: cpuCard
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 76
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: "CPU details"
                            radius: Theme.smallRadius
                            color: root.metricSurface(ShellState.cpuUsage, Theme.accent)
                            border.width: activeFocus ? 1 : 0
                            border.color: Theme.accent

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                                    event.accepted = true
                                    cpuTooltip.dismiss()
                                    UiState.popupPage = "system"
                                }
                            }
                            Accessible.onPressAction: {
                                cpuTooltip.dismiss()
                                UiState.popupPage = "system"
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 11
                                spacing: 3
                                Text {
                                    text: "CPU"
                                    color: Theme.muted
                                    font.pixelSize: Theme.smallFontSize
                                    font.family: Theme.fontFamily
                                }
                                Text {
                                    text: ShellState.cpuUsage + "%"
                                    color: root.metricAccent(ShellState.cpuUsage, Theme.text)
                                    font.pixelSize: 21
                                    font.family: Theme.fontFamily
                                    font.weight: Font.DemiBold
                                }
                                MeterBar {
                                    value: ShellState.cpuUsage / 100
                                    fillColor: root.metricAccent(ShellState.cpuUsage, Theme.accent)
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                }
                            }

                            MouseArea {
                                id: cpuMouse
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                hoverEnabled: true
                                onPressed: {
                                    cpuTooltip.dismiss()
                                    cpuCard.forceActiveFocus(Qt.MouseFocusReason)
                                }
                                onClicked: UiState.popupPage = "system"
                            }
                            HoverTooltip {
                                id: cpuTooltip
                                targetItem: cpuCard
                                hovered: cpuMouse.containsMouse
                                focused: cpuCard.activeFocus
                                text: "CPU usage: " + ShellState.cpuUsage + "%\n" + root.cpuDetails()
                                delay: 500
                            }
                        }

                        Rectangle {
                            id: memoryCard
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 76
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: "Memory details"
                            radius: Theme.smallRadius
                            color: root.metricSurface(ShellState.memoryUsage, Theme.accentAlt)
                            border.width: activeFocus ? 1 : 0
                            border.color: Theme.accentAlt

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                                    event.accepted = true
                                    memoryTooltip.dismiss()
                                    UiState.popupPage = "system"
                                }
                            }
                            Accessible.onPressAction: {
                                memoryTooltip.dismiss()
                                UiState.popupPage = "system"
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 11
                                spacing: 3
                                Text {
                                    text: "Memory"
                                    color: Theme.muted
                                    font.pixelSize: Theme.smallFontSize
                                    font.family: Theme.fontFamily
                                }
                                Text {
                                    text: ShellState.memoryUsage + "%"
                                    color: root.metricAccent(ShellState.memoryUsage, Theme.text)
                                    font.pixelSize: 21
                                    font.family: Theme.fontFamily
                                    font.weight: Font.DemiBold
                                }
                                MeterBar {
                                    value: ShellState.memoryUsage / 100
                                    fillColor: root.metricAccent(ShellState.memoryUsage, Theme.accentAlt)
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                }
                            }

                            MouseArea {
                                id: memoryMouse
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                hoverEnabled: true
                                onPressed: {
                                    memoryTooltip.dismiss()
                                    memoryCard.forceActiveFocus(Qt.MouseFocusReason)
                                }
                                onClicked: UiState.popupPage = "system"
                            }
                            HoverTooltip {
                                id: memoryTooltip
                                targetItem: memoryCard
                                hovered: memoryMouse.containsMouse
                                focused: memoryCard.activeFocus
                                text: root.memoryTooltip()
                                delay: 500
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: 58
                        spacing: 8
                        ActionTile {
                            icon: !ShellState.networkConnected ? "󰤭" : (ShellState.networkType === "ethernet" ? "" : "󰤨")
                            title: ShellState.networkConnected ? ShellState.networkLabel : "Offline"
                            subtitle: ShellState.networkConnected ? ShellState.networkName : "No active connection"
                            accent: ShellState.networkConnected ? Theme.accentAlt : Theme.danger
                            Layout.fillWidth: true
                            onClicked: UiState.popupPage = "network"
                        }
                        ActionTile {
                            icon: ShellState.bluetoothPowered ? "󰂯" : "󰂲"
                            title: "Bluetooth"
                            subtitle: ShellState.bluetoothConnected || "No connected devices"
                            accent: ShellState.bluetoothPowered ? Theme.accentAlt : Theme.subtle
                            Layout.fillWidth: true
                            onClicked: UiState.popupPage = "bluetooth"
                        }
                    }

                    Rectangle {
                        visible: MediaState.available
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: 74
                        radius: Theme.smallRadius
                        color: Theme.backgroundElevated

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 11
                            spacing: 8
                            Text { text: "󰎆"; color: Theme.accent; font.pixelSize: 23; font.family: Theme.fontFamily }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: MediaState.title; color: Theme.text; font.pixelSize: Theme.bodyFontSize; font.family: Theme.fontFamily; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { text: MediaState.artist; color: Theme.muted; font.pixelSize: Theme.smallFontSize; font.family: Theme.fontFamily; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                            IconButton { icon: "󰒮"; tooltip: "Previous"; onClicked: MediaState.command("previous") }
                            IconButton { icon: MediaState.playing ? "󰏤" : "󰐊"; tooltip: "Play or pause"; onClicked: MediaState.command("play-pause") }
                            IconButton { icon: "󰒭"; tooltip: "Next"; onClicked: MediaState.command("next") }
                        }
                    }

                    ActionTile {
                        icon: "󰕾"
                        title: "Audio"
                        subtitle: ShellState.audioShowSource ? ShellState.sourceName : ShellState.sinkName
                        accent: Theme.accentAlt
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: 58
                        Layout.minimumWidth: 0
                        onClicked: UiState.popupPage = "audio"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: 48
                        radius: Theme.smallRadius
                        color: Theme.backgroundElevated

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                text: "Brightness"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                Layout.preferredWidth: 66
                            }

                            Text {
                                text: ShellState.brightness + "%"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.bodyFontSize
                                Layout.preferredWidth: 34
                                horizontalAlignment: Text.AlignRight
                            }

                            ValueSlider {
                                value: ShellState.brightness / 100
                                accent: Theme.warning
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                onMoved: ShellState.setBrightness(value)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: 58
                        spacing: 8
                        ActionTile { icon: "󰌾"; title: "Lock"; subtitle: "Session"; accent: Theme.warning; enabled: !PowerState.running; Layout.fillWidth: true; onClicked: PowerState.runImmediate([Commands.swaylock, "-f"]) }
                        ActionTile { icon: "󰐥"; title: "Power"; subtitle: "Session actions"; accent: Theme.danger; Layout.fillWidth: true; onClicked: UiState.popupPage = "power" }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 9

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        clip: true
                        radius: Theme.smallRadius
                        color: root.metricSurface(ShellState.cpuUsage, Theme.accent)
                        border.width: 0
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            Text {
                                text: "󰻠"
                                color: root.metricAccent(ShellState.cpuUsage, Theme.accent)
                                font.family: Theme.fontFamily
                                font.pixelSize: 22
                                horizontalAlignment: Text.AlignHCenter
                                Layout.preferredWidth: root.metricIconWidth
                                Layout.minimumWidth: root.metricIconWidth
                                Layout.maximumWidth: root.metricIconWidth
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 2
                                Text {
                                    text: "CPU"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.bodyFontSize
                                }
                                Text {
                                    text: ShellState.cpuUsage + "% · " + ShellState.metricSeverity(ShellState.cpuUsage)
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.smallFontSize
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                }
                                Text {
                                    text: root.cpuDetails()
                                    color: Theme.subtle
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                }
                            }
                            MeterBar {
                                value: ShellState.cpuUsage / 100
                                fillColor: root.metricAccent(ShellState.cpuUsage, Theme.accent)
                                Layout.preferredWidth: root.metricBarWidth
                                Layout.minimumWidth: root.metricBarWidth
                                Layout.maximumWidth: root.metricBarWidth
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        clip: true
                        radius: Theme.smallRadius
                        color: root.metricSurface(ShellState.memoryUsage, Theme.accentAlt)
                        border.width: 0
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            Text {
                                text: ""
                                color: root.metricAccent(ShellState.memoryUsage, Theme.accentAlt)
                                font.family: Theme.fontFamily
                                font.pixelSize: 22
                                horizontalAlignment: Text.AlignHCenter
                                Layout.preferredWidth: root.metricIconWidth
                                Layout.minimumWidth: root.metricIconWidth
                                Layout.maximumWidth: root.metricIconWidth
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 2
                                Text {
                                    text: "Memory"
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.bodyFontSize
                                }
                                Text {
                                    text: gib(ShellState.memoryUsedMiB) + " / " + gib(ShellState.memoryTotalMiB)
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.smallFontSize
                                }
                                Text {
                                    text: "Swap " + gib(ShellState.swapUsedMiB) + " / " + gib(ShellState.swapTotalMiB)
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.smallFontSize
                                }
                            }
                            MeterBar {
                                value: ShellState.memoryUsage / 100
                                fillColor: root.metricAccent(ShellState.memoryUsage, Theme.accentAlt)
                                Layout.preferredWidth: root.metricBarWidth
                                Layout.minimumWidth: root.metricBarWidth
                                Layout.maximumWidth: root.metricBarWidth
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: Theme.smallRadius
                            color: Theme.backgroundElevated
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                Text { text: "Temperature"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.smallFontSize }
                                Text { text: ShellState.temperature > 0 ? ShellState.temperature + "°C" : "Unavailable"; color: ShellState.temperature >= 80 ? Theme.danger : Theme.text; font.family: Theme.fontFamily; font.pixelSize: 15 }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: Theme.smallRadius
                            color: Theme.backgroundElevated
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                Text { text: "Battery"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.smallFontSize }
                                Text { text: ShellState.batteryStatus === "Unknown" ? "Unavailable" : ShellState.batteryLevel + "% · " + ShellState.batteryStatus; color: ShellState.batterySeverity() === "critical" ? Theme.danger : (ShellState.batterySeverity() === "warning" ? Theme.warning : Theme.text); font.family: Theme.fontFamily; font.pixelSize: 13 }
                            }
                        }
                    }

                    ActionTile { icon: "󰆍"; title: "Open btop"; subtitle: "Process, CPU, memory, and swap monitor"; accent: Theme.accentAlt; Layout.fillWidth: true; onClicked: ShellState.run([Commands.btop]) }

                    Rectangle {
                        visible: ShellState.audioInUse || ShellState.screenShareActive || ShellState.idleInhibited || ShellState.isBedtime()
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: Theme.smallRadius
                        color: Theme.backgroundElevated
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8
                            Text { text: "Privacy"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.smallFontSize }
                            Text { Layout.fillWidth: true; text: (ShellState.audioInUse ? "󰍬 Mic " : "") + (ShellState.screenShareActive ? "󰖟 Share " : "") + (ShellState.idleInhibited ? " Idle " : "") + (ShellState.isBedtime() ? "󰋣 Bedtime" : ""); color: Theme.warning; font.family: Theme.fontFamily; font.pixelSize: 11; elide: Text.ElideRight }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12
                    Text { text: "Output"; color: Theme.muted; font.pixelSize: Theme.smallFontSize; font.family: Theme.fontFamily }
                    Text { text: ShellState.sinkName; color: Theme.text; font.pixelSize: 14; font.family: Theme.fontFamily; elide: Text.ElideRight; maximumLineCount: 1; clip: true; Layout.fillWidth: true; Layout.minimumWidth: 0 }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: ShellState.sinkMuted ? "Muted" : Math.round(ShellState.sinkVolume * 100) + "%"; color: Theme.text; font.pixelSize: Theme.bodyFontSize; font.family: Theme.fontFamily }
                        ValueSlider { value: ShellState.sinkVolume; accent: Theme.accentAlt; Layout.fillWidth: true; onMoved: ShellState.setVolume(value) }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        IconButton { icon: ShellState.sinkMuted ? "󰖁" : "󰕾"; label: ShellState.sinkMuted ? "Unmute" : "Mute"; onClicked: ShellState.toggleMute() }
                        IconButton { icon: "󰽴"; label: "Mixer"; onClicked: ShellState.run([Commands.pavucontrol]) }
                        Item { Layout.fillWidth: true }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.surfaceStrong }
                    Text { text: "Input"; color: Theme.muted; font.pixelSize: Theme.smallFontSize; font.family: Theme.fontFamily }
                    Text { text: ShellState.sourceName; color: Theme.text; font.pixelSize: 14; font.family: Theme.fontFamily; elide: Text.ElideRight; maximumLineCount: 1; clip: true; Layout.fillWidth: true; Layout.minimumWidth: 0 }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: ShellState.sourceMuted ? "Muted" : Math.round(ShellState.sourceVolume * 100) + "%"; color: Theme.text; font.pixelSize: Theme.bodyFontSize; font.family: Theme.fontFamily }
                        ValueSlider { value: ShellState.sourceVolume; accent: Theme.warning; Layout.fillWidth: true; onMoved: ShellState.setSourceVolume(value) }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        IconButton { icon: ShellState.sourceMuted ? "󰍭" : "󰍬"; label: ShellState.sourceMuted ? "Unmute" : "Mute"; onClicked: ShellState.toggleSourceMute() }
                        IconButton { icon: "󰋌"; label: "Show input"; selected: ShellState.audioShowSource; onClicked: ShellState.toggleAudioDisplay() }
                        Item { Layout.fillWidth: true }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: ShellState.networkConnected ? ShellState.networkName : "Offline"; color: Theme.text; font.pixelSize: 16; font.family: Theme.fontFamily; Layout.fillWidth: true; elide: Text.ElideRight }
                        IconButton { visible: ShellState.networkType === "wifi" || !ShellState.networkConnected; icon: ShellState.wifiEnabled ? "󰖩" : "󰖪"; label: ShellState.wifiEnabled ? "On" : "Off"; selected: ShellState.wifiEnabled; onClicked: ShellState.toggleWifi() }
                    }
                    MeterBar { value: ShellState.networkSignal / 100; fillColor: ShellState.networkConnected ? Theme.accentAlt : Theme.danger; Layout.fillWidth: true }
                    Text { text: ShellState.networkLabel + (ShellState.networkSignal > 0 ? " · " + ShellState.networkSignal + "%" : ""); color: Theme.muted; font.pixelSize: 11; font.family: Theme.fontFamily }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 84
                        radius: Theme.smallRadius
                        color: Theme.backgroundElevated
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 11
                            spacing: 3
                            Text { text: "Interface: " + (ShellState.networkInterface || "-"); color: Theme.text; font.pixelSize: 11; font.family: Theme.fontFamily }
                            Text { text: "Address: " + (ShellState.networkAddress || "-"); color: Theme.muted; font.pixelSize: Theme.smallFontSize; font.family: Theme.fontFamily }
                            Text { text: "Gateway: " + (ShellState.networkGateway || "-"); color: Theme.muted; font.pixelSize: Theme.smallFontSize; font.family: Theme.fontFamily }
                        }
                    }
                    ActionTile { icon: "󰖩"; title: "Network connections"; subtitle: "Manage saved networks and VPNs"; accent: Theme.accentAlt; Layout.fillWidth: true; onClicked: ShellState.run([Commands.nmEditor]) }
                    ActionTile { icon: "󰒓"; title: "Refresh status"; subtitle: "Read NetworkManager state again"; accent: Theme.muted; Layout.fillWidth: true; onClicked: ShellState.refreshNativeState() }
                    Item { Layout.fillHeight: true }
                }
            }

            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 9
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: ShellState.bluetoothPowered ? "Bluetooth ready" : "Bluetooth off"; color: Theme.text; font.pixelSize: 16; font.family: Theme.fontFamily; Layout.fillWidth: true }
                        IconButton { icon: ShellState.bluetoothPowered ? "󰂯" : "󰂲"; label: ShellState.bluetoothPowered ? "On" : "Off"; selected: ShellState.bluetoothPowered; onClicked: ShellState.toggleBluetooth() }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 54
                        radius: Theme.smallRadius
                        color: Theme.backgroundElevated
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 2
                            Text { text: ShellState.bluetoothControllerName || "No adapter"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.bodyFontSize }
                            Text { text: ShellState.bluetoothControllerAddress || "Address unavailable"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.smallFontSize }
                        }
                    }
                    Text { visible: ShellState.bluetoothDevices.length > 0; text: "Connected devices"; color: Theme.muted; font.pixelSize: Theme.smallFontSize; font.family: Theme.fontFamily }
                    ScriptModel {
                        id: bluetoothModel
                        values: ShellState.bluetoothDevices
                        objectProp: "id"
                    }
                    Repeater {
                        model: bluetoothModel
                        delegate: Rectangle {
                            id: deviceCard
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: "Open " + modelData.name + " in Bluetooth manager"
                            radius: Theme.smallRadius
                            color: deviceMouse.containsMouse || activeFocus ? Theme.surface : Theme.backgroundElevated
                            border.width: activeFocus ? 1 : 0
                            border.color: Theme.accentAlt
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                                    event.accepted = true
                                    deviceTooltip.dismiss()
                                    ShellState.run([Commands.blueman])
                                }
                            }
                            Accessible.onPressAction: {
                                deviceTooltip.dismiss()
                                ShellState.run([Commands.blueman])
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8
                                Text { text: "󰂱"; color: Theme.accentAlt; font.family: Theme.fontFamily; font.pixelSize: 19 }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text { text: modelData.name; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text { text: modelData.address || "Address unavailable"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: 9 }
                                }
                                Text { visible: modelData.battery >= 0; text: Math.round(modelData.battery) + "%"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 11 }
                            }
                            HoverTooltip {
                                id: deviceTooltip
                                targetItem: deviceCard
                                hovered: deviceMouse.containsMouse
                                focused: deviceCard.activeFocus
                                text: modelData.name + "\n" + (modelData.address || "Address unavailable") + (modelData.battery >= 0 ? "\nBattery: " + Math.round(modelData.battery) + "%" : "")
                                delay: 450
                            }
                            MouseArea {
                                id: deviceMouse
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                hoverEnabled: true
                                onPressed: {
                                    deviceTooltip.dismiss()
                                    deviceCard.forceActiveFocus(Qt.MouseFocusReason)
                                }
                                onClicked: ShellState.run([Commands.blueman])
                            }
                        }
                    }
                    Text { visible: ShellState.bluetoothDevices.length === 0; text: "No connected devices"; color: Theme.muted; font.pixelSize: Theme.bodyFontSize; font.family: Theme.fontFamily }
                    ActionTile { icon: "󰂱"; title: "Bluetooth manager"; subtitle: "Pair, connect, and rename devices"; accent: Theme.accentAlt; Layout.fillWidth: true; onClicked: ShellState.run([Commands.blueman]) }
                    ActionTile { icon: "󰒓"; title: "Refresh status"; subtitle: "Read BlueZ state again"; accent: Theme.muted; Layout.fillWidth: true; onClicked: ShellState.refreshNativeServices() }
                    Item { Layout.fillHeight: true }
                }
            }

            FanPage { }

            RgbPage { }

            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        IconButton { icon: "󰅁"; tooltip: "Previous month"; onClicked: ShellState.shiftCalendar(-1) }
                        Text { text: ShellState.calendarTitle; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                        IconButton { icon: "󰅂"; tooltip: "Next month"; onClicked: ShellState.shiftCalendar(1) }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Repeater {
                            model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                            delegate: Text {
                                required property string modelData
                                text: modelData
                                color: Theme.muted
                                font.pixelSize: Theme.smallFontSize
                                font.family: Theme.fontFamily
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }
                        }
                    }
                    MonthGrid {
                        id: monthGrid
                        month: ShellState.calendarMonth
                        year: ShellState.calendarYear
                        locale: Qt.locale("en_GB")
                        spacing: 4
                        Layout.fillWidth: true
                        Layout.preferredHeight: 224
                        delegate: Rectangle {
                            required property var model
                            readonly property bool todayCell: model.today && model.month === monthGrid.month && model.year === monthGrid.year
                            width: monthGrid.width / 7 - 4
                            height: 32
                            radius: 7
                            color: todayCell ? Theme.accent : "transparent"
                            border.width: 0
                            Text { anchors.centerIn: parent; text: model.day; color: todayCell ? Theme.background : (model.month === monthGrid.month ? Theme.text : Theme.subtle); font.family: Theme.fontFamily; font.pixelSize: 11 }
                        }
                    }
                    Text { text: "Today: " + Qt.formatDate(ShellState.now, "yyyy-MM-dd"); color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.smallFontSize; Layout.alignment: Qt.AlignHCenter }
                    Item { Layout.fillHeight: true }
                }
            }

            TaskPage { }

            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    Rectangle {
                        visible: PowerState.confirmationPending || PowerState.errorMessage.length > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? 48 : 0
                        radius: Theme.smallRadius
                        color: Theme.tint(Theme.danger, 0.12)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            anchors.rightMargin: 6
                            spacing: 6
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: PowerState.confirmationPending
                                    ? "Confirm " + PowerState.confirmationLabel + "?"
                                    : PowerState.errorMessage
                                color: Theme.danger
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.bodyFontSize
                                elide: Text.ElideRight
                            }
                            IconButton { visible: PowerState.confirmationPending; label: "Cancel"; tooltip: "Cancel power action"; onClicked: PowerState.cancelConfirmation() }
                            IconButton { visible: PowerState.confirmationPending; label: "Confirm"; tooltip: "Confirm " + PowerState.confirmationLabel; iconColor: Theme.danger; onClicked: PowerState.confirm() }
                        }
                    }

                    ActionTile { icon: "󰌾"; title: "Lock session"; subtitle: "Keep applications running"; accent: Theme.warning; enabled: !PowerState.running; opacity: enabled ? 1 : 0.45; Layout.fillWidth: true; Layout.preferredHeight: 58; onClicked: PowerState.runImmediate([Commands.swaylock, "-f"]) }
                    ActionTile { icon: "󰤄"; title: "Suspend"; subtitle: "Sleep until you return"; accent: Theme.accentAlt; enabled: !PowerState.running; opacity: enabled ? 1 : 0.45; Layout.fillWidth: true; Layout.preferredHeight: 58; onClicked: PowerState.runImmediate([Commands.systemctl, "suspend"]) }
                    ActionTile { icon: "󰒲"; title: "Hibernate"; subtitle: "Save state to disk"; accent: Theme.accentAlt; enabled: !PowerState.running; opacity: enabled ? 1 : 0.45; Layout.fillWidth: true; Layout.preferredHeight: 58; onClicked: PowerState.request("hibernate", "hibernate") }
                    ActionTile { icon: "󰜉"; title: "Reboot"; subtitle: "Restart the computer"; accent: Theme.warning; enabled: !PowerState.running; opacity: enabled ? 1 : 0.45; Layout.fillWidth: true; Layout.preferredHeight: 58; onClicked: PowerState.request("reboot", "reboot") }
                    ActionTile { icon: "󰐥"; title: "Power off"; subtitle: "Shut down the computer"; accent: Theme.danger; enabled: !PowerState.running; opacity: enabled ? 1 : 0.45; Layout.fillWidth: true; Layout.preferredHeight: 58; onClicked: PowerState.request("poweroff", "power off") }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
