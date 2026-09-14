import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RowLayout {
    id: netRoot
    spacing: 4
    Layout.alignment: Qt.AlignVCenter

    // --- BANDWIDTH CONSUMPTION BACKEND VARIABLES ---
    property string targetInterface: "eth0" // Default wlan0. Change to "eth0" or "enp3s0" if using ethernet!

    property real lastRxBytes: 0
    property real lastTxBytes: 0

    property string downloadSpeedStr: "0.0 KiB/s"
    property string uploadSpeedStr: "0.0 KiB/s"

    // Asynchronous engine to pull raw network traffic blocks straight from the Linux kernel
    Process {
        id: netReader
        command: ["cat", "/proc/net/dev"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim();

                    // Locate your active network device row card string
                    if (line.startsWith(netRoot.targetInterface + ":")) {
                        // Strip the interface header prefix and clean up whitespace groupings
                        let stats = line.substring(line.indexOf(":") + 1).trim().split(/\s+/);

                        // Linux Kernel Array Layout Mapping: Index 0 = Received Bytes, Index 8 = Transmitted Bytes
                        let rxBytes = parseFloat(stats[0]);
                        let txBytes = parseFloat(stats[8]);

                        if (netRoot.lastRxBytes > 0 && netRoot.lastTxBytes > 0) {
                            // Calculate byte displacement difference since our last 1-second clock sweep tick
                            let rxDiff = rxBytes - netRoot.lastRxBytes;
                            let txDiff = txBytes - netRoot.lastTxBytes;

                            netRoot.downloadSpeedStr = formatSpeed(rxDiff);
                            netRoot.uploadSpeedStr = formatSpeed(txDiff);
                        }

                        // Update delta tracking properties for our next second interval analysis loop
                        netRoot.lastRxBytes = rxBytes;
                        netRoot.lastTxBytes = txBytes;
                        break;
                    }
                }
            }
        }
    }

    // High-precision clock sequence generator driving our real-time metric updates
    Timer {
        interval: 1000 // Refreshes exactly once every 1.0 seconds
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            netReader.running = true;
        }
    }

    // Helper JavaScript function to dynamically scale byte strings into KiB or MiB ranges cleanly
    function formatSpeed(bytes) {
        let kib = bytes / 1024;
        if (kib < 1024) {
            return kib.toFixed(1) + " KiB/s";
        }
        let mib = kib / 1024;
        return mib.toFixed(1) + " MiB/s";
    }

    // ================= DYNAMIC BAR INTERFACE TEXT BLOCK =================
    RowLayout {
        spacing: 10

        // 1. DOWNLOAD READOUT MODULE
        RowLayout {
            spacing: 4
            Text {
                text: "" // Nerd Font Download Arrow Glyph
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: "#a6e3a1" // Catppuccin Pastel Green
            }
            Text {
                text: netRoot.downloadSpeedStr
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.bold: true
                color: "#cdd6f4"
            }
        }

        // 2. UPLOAD READOUT MODULE
        RowLayout {
            spacing: 4
            Text {
                text: "" // Nerd Font Upload Arrow Glyph
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: "#f38ba8" // Catppuccin Pastel Red
            }
            Text {
                text: netRoot.uploadSpeedStr
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.bold: true
                color: "#cdd6f4"
            }
        }
    }
}
