import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.I3
import Quickshell.Io 

RowLayout {
    id: activeWindowRoot

    property string windowTitle: ""

    // 1. FIXED: Native connection observer tracking workspace hopping events instantly
    Connections {
        target: I3
        function onFocusedWorkspaceChanged() {
            // Instantly tell our native looping shell engine to fetch a fresh name string
            titleCommandEngine.running = false;
            titleCommandEngine.running = true;
        }
    }

    // 2. FIXED: Fully streaming unbuffered event handler. It stays permanently running.
    Process {
        id: titleCommandEngine
        running: true
        // Listens to window and workspace updates natively and pulls the focused name via jq instantly
        command: [
            "sh", "-c", 
            "i3-msg -t get_tree | jq -r 'recurse(.nodes[]; .nodes != null) | select(.focused == true) | .name'; " +
            "stdbuf -oL i3-msg -t subscribe '[\"window\",\"workspace\"]' | while read -r line; do " +
            "  i3-msg -t get_tree | jq -r 'recurse(.nodes[]; .nodes != null) | select(.focused == true) | .name'; " +
            "done"
        ]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                let title = line.trim();
                
                // Catch cases where i3 points to null containers or the empty workspace wrapper node
                if (title === "null" || title === "" || title.startsWith("workspace_")) {
                    activeWindowRoot.windowTitle = "";
                } else {
                    activeWindowRoot.windowTitle = title;
                }
            }
        }
    }

    Text {
        id: titleText
        text: activeWindowRoot.windowTitle !== "" ? activeWindowRoot.windowTitle : "Desktop"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        font.weight: Font.Medium
        color: "#a9b1d6"

        elide: Text.ElideRight
        Layout.maximumWidth: 400
        Layout.fillWidth: true
    }
}
