import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RowLayout {
    id: tempRoot
    spacing: 12
    Layout.alignment: Qt.AlignVCenter

    // --- SYSTEM HARDWARE CONFIGURATION CHANNELS ---
    // Update these index values based on your terminal's path diagnostic scan!
    property string cpuZoneIndex: "thermal_zone0"
    property string gpuZoneIndex: "thermal_zone1" // Leave blank or remove if on a headless box

    property int cpuTempCelsius: 0
    property int gpuTempCelsius: 0

    // ASYNC KERNEL CORE 1: Query CPU Thermal State Registers
    Process {
        id: cpuTempReader
        command: ["cat", "/sys/class/thermal/" + tempRoot.cpuZoneIndex + "/temp"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let rawValue = parseFloat(text.trim());
                if (!isNaN(rawValue)) {
                    // Kernel registers store temperatures in millidegrees (e.g. 45000 = 45C)
                    tempRoot.cpuTempCelsius = Math.round(rawValue / 1000);
                }
            }
        }
    }

    // ASYNC KERNEL CORE 2: Query GPU Thermal State Registers
    Process {
        id: gpuTempReader
        command: ["cat", "/sys/class/thermal/" + tempRoot.gpuZoneIndex + "/temp"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let rawValue = parseFloat(text.trim());
                if (!isNaN(rawValue)) {
                    tempRoot.gpuTempCelsius = Math.round(rawValue / 1000);
                }
            }
        }
    }

    // Master High-Precision Pacing Clock (Triggers updates smoothly once every 2 seconds)
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuTempReader.running = true;
            if (tempRoot.gpuZoneIndex !== "") {
                gpuTempReader.running = true;
            }
        }
    }

    // HELPER COLOR FUNCTION: Transitions beautifully through a Catppuccin palette based on stress
    function getDynamicColor(temp) {
        if (temp === 0) return "#cdd6f4";   // Default Text Soft White
        if (temp < 55) return "#89b4fa";    // Cool: Catppuccin Blue
        if (temp < 75) return "#f9e2af";    // Warm: Catppuccin Pastel Yellow
        return "#f38ba8";                   // Hot Danger Limit: Catppuccin Vibrant Red
    }

    // ================= DYNAMIC TEXT RENDERING VIEW DECK =================
    RowLayout {
        spacing: 4

        // 1. CPU TEMPERATURE INTERFACE COMPONENT
        RowLayout {
            spacing: 4
            Text {
                text: "" // Nerd Font CPU Chip Icon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: tempRoot.getDynamicColor(tempRoot.cpuTempCelsius)
            }
            Text {
                text: tempRoot.cpuTempCelsius > 0 ? tempRoot.cpuTempCelsius + "°C" : "--°C"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.bold: true
                color: "#cdd6f4"
            }
        }

        // 2. GPU TEMPERATURE INTERFACE COMPONENT (Only renders if mapped)
        RowLayout {
            spacing: 4
            visible: tempRoot.gpuZoneIndex !== ""

            Text {
                text: "|" // Nerd Font Graphics Card Icon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: tempRoot.getDynamicColor(tempRoot.gpuTempCelsius)
            }
            Text {
                text: tempRoot.gpuTempCelsius > 0 ? tempRoot.gpuTempCelsius + "°C" : "--°C"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.bold: true
                color: "#cdd6f4"
            }
        }
    }
}
