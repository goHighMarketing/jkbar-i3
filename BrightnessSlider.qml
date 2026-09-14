import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Requires brightnessctl
// If brightnessctl slider isn't changing monitor brightness, run this command in the console:
// sudo chmod +s $(which brightnessctl)

RowLayout {
    id: brightnessRoot
    spacing: 12

    // Core property to hold the active percentage (0.0 to 1.0)
    property real brightnessLevel: 0.5

    // FIXED: Unified single-process baseline query to fetch max and current raw details instantly
    Process {
        id: initBrightness
        command: ["sh", "-c", "cur=$(brightnessctl g); max=$(brightnessctl m); echo \"$cur $max\""]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                let parts = line.trim().split(" ");
                if (parts.length === 2) {
                    let cur = parseFloat(parts[0]);
                    let max = parseFloat(parts[1]);
                    if (max > 0) {
                        brightnessRoot.brightnessLevel = cur / max;
                    }
                }
            }
        }
    }

    // Dynamic Icon Indicator
    Text {
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 16
        color: "#f9e2af" // Catppuccin Pastel Yellow
        Layout.alignment: Qt.AlignVCenter

        // FIXED: Restored functional Nerd Font brightness level glyphs
        text: {
            if (brightnessRoot.brightnessLevel < 0.3) return "   "; // Low
            if (brightnessRoot.brightnessLevel < 0.7) return "   "; // Medium
            return "   "; // Full Brightness
        }
    }

    // High-Fidelity Interaction Slider Track
    Slider {
        id: brightnessSlider
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter

        from: 0.05 // Cap low bound at 5% so your screen never goes completely black!
        to: 1.0

        // FIXED: Use a declarative binding expression to prevent recursive valuation locks
        Binding on value {
            value: brightnessRoot.brightnessLevel
            when: !brightnessSlider.pressed // Only follow external state when NOT dragging
        }

        // Handle active sliding movements instantly
        onMoved: {
            let percentValue = Math.round(value * 100);
            brightnessRoot.brightnessLevel = value; // Keep state in sync

            // Fires an unblocked hardware execution instruction straight to your display device
            Quickshell.execDetached(["brightnessctl", "s", percentValue + "%"]);
        }

        // Custom Styling matching your premium dark aesthetics
        background: Rectangle {
            x: brightnessSlider.leftPadding
            y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
            implicitWidth: 100 // Constrained width line so it sits cleanly inside a dense bar row
            implicitHeight: 4
            width: brightnessSlider.availableWidth
            height: implicitHeight
            radius: 2
            color: "#313244" // Track background channel line

            Rectangle {
                width: brightnessSlider.visualPosition * parent.width
                height: parent.height
                color: "#f9e2af" // Active filled track line
                radius: 2
            }
        }

        handle: Rectangle {
            x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
            y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
            implicitWidth: 12
            implicitHeight: 12
            radius: 6
            color: brightnessSlider.hovered ? "#ffe599" : "#f9e2af"
            border.color: "#11111b"
            border.width: 1
        }
    }

    // Visual Percentage Text Readout
    Text {
        text: Math.round(brightnessRoot.brightnessLevel * 100) + "%"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        font.bold: true
        color: "#cdd6f4"
        width: 35
        horizontalAlignment: Text.AlignRight
        Layout.alignment: Qt.AlignVCenter
    }
}
 