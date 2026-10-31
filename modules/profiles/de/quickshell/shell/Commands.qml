pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property string niri: "@niri@"
    readonly property string focusWorkspace: "@focusWorkspace@"
    readonly property string btop: "@btop@"
    readonly property bool taskEnabled: "@taskEnabled@" === "true"
    readonly property string task: "@task@"
    readonly property string taskTerminal: "@taskTerminal@"
    readonly property string python: "@python@"
    readonly property string sampler: "@sampler@"
    readonly property string pwDump: "@pwDump@"
    readonly property string ip: "@ip@"
    readonly property string nmcli: "@nmcli@"
    readonly property string bluetoothctl: "@bluetoothctl@"
    readonly property string brightnessctl: "@brightnessctl@"
    readonly property string wpctl: "@wpctl@"
    readonly property string systemctl: "@systemctl@"
    readonly property string loginctl: "@loginctl@"
    readonly property string swaylock: "@swaylock@"
    readonly property string pavucontrol: "@pavucontrol@"
    readonly property string nmEditor: "@nmEditor@"
    readonly property string blueman: "@blueman@"
    readonly property string wpaperctl: "@wpaperctl@"
    readonly property string playerctl: "@playerctl@"
    readonly property string cava: "@cava@"
    readonly property string cavaConfig: "@cavaConfig@"
    readonly property bool fanEnabled: "@fanEnabled@" === "true"
    readonly property string fanControl: "@fanControl@"
    readonly property bool rgbEnabled: "@rgbEnabled@" === "true"
    readonly property string rgbControl: "@rgbControl@"
}
