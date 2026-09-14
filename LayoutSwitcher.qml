import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.I3
import Quickshell.Io

MouseArea {
    id: layoutRoot

    implicitWidth: layoutRow.implicitWidth + 8
    implicitHeight: 24
    hoverEnabled: true
   // cursorShape: Qt.PointingHandCursor

    // The Display State Variable
    property string activeLayout: "splith"

    // FIXED: Listens to the native C++ i3 engine to handle instant workspace hopping
    Connections {
        target: I3
        function onFocusedWorkspaceChanged() {
            checkCurrentLayout.running = false;
            checkCurrentLayout.running = true;
        }
    }

    // --- CONTINUOUS LAYOUT EVENT TRACKER ---
    // Safely reads the stream from i3 natively to handle glyph styling updates
    Process {
        running: true
        command: ["sh", "-c", "stdbuf -oL i3-msg -t subscribe '[\"window\",\"workspace\"]'"]
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                // Whenever i3 triggers any change, fire our safe inline layout checker
                checkCurrentLayout.running = false;
                checkCurrentLayout.running = true;
            }
        }
    }

    // Secondary sub-process to accurately fetch the layout format without caching bugs
    property Process checkCurrentLayout: Process {
        running: false
        command: ["sh", "-c", "i3-msg -t get_tree | jq -r 'recurse(.nodes[]; .nodes != null) | select(.nodes[].focused == true) | .layout'"]
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                let layout = line.trim();
                if (layout === "tabbed") {
                    layoutRoot.activeLayout = "tabbed";
                } else {
                    layoutRoot.activeLayout = "splith"; // Maps splitv/splith/stacked to standard splith
                }
            }
        }
    }

    // --- INTERACTIVE CLICK TOGGLE ---
    onClicked: {
        // Toggles precisely between tabbed and splith based on the live evaluated string
        if (layoutRoot.activeLayout === "splith") {
            I3.dispatch("layout tabbed");
            layoutRoot.activeLayout = "tabbed"; // Optimistic visual feedback
        } else {
            I3.dispatch("layout splith");
            layoutRoot.activeLayout = "splith"; // Optimistic visual feedback
        }
    }

    // Baseline initializer to capture the correct layout format on startup
    Component.onCompleted: {
        checkCurrentLayout.running = true;
    }

    // Visual Presentation Layer
    RowLayout {
        id: layoutRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            Layout.alignment: Qt.AlignVCenter

            text: (layoutRoot.activeLayout === "tabbed") ? "" : "" 
            color: (layoutRoot.activeLayout === "tabbed") ? "#b4befe" : "#a6e3a1" 
        }

        Text {
            text: layoutRoot.activeLayout.toUpperCase()
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            font.bold: true
            color: layoutRoot.hovered ? "#ffffff" : "#cdd6f4"
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
