import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

MouseArea {
    id: clockRoot

    // Explicit sizing for a clean, non-collapsing layout on your bar
    implicitWidth: clockText.implicitWidth + 10
    implicitHeight: 24
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    // State properties
    property bool showSeconds: false
    property var currentTime: new Date()

    // Process to run gsimplecal as a detached desktop applet
    Process {
        id: runCal
        command: ["gsimplecal"]
    }

    // A 1-second timer to drive the live clock updates
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            clockRoot.currentTime = new Date();
        }
    }

    // Helper functions to format the QML JavaScript Date
    function formatTime() {
    const currTime = new Date();
    let month = String(currTime.getMonth() + 1).padStart(2, '0');
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const monthText = months[currTime.getMonth()];
        let day = String(currentTime.getDate()).padStart(2, '0');
        let hours = String(currentTime.getHours()).padStart(2, '0');
        let minutes = String(currentTime.getMinutes()).padStart(2, '0');
        let seconds = String(currentTime.getSeconds()).padStart(2, '0');

        if (showSeconds) {
            let year = currentTime.getFullYear();
            let month = String(currentTime.getMonth() + 1).padStart(2, '0');
            let day = String(currentTime.getDate()).padStart(2, '0');
            return `${year}-${month}-${day}  ${hours}:${minutes}:${seconds}`;
        } else {
            return `${monthText} ${day}   ${hours}:${minutes}`;
        }
    }

    // Left click toggles seconds, right click spawns the calendar
    onClicked: (mouse) => {
        if (mouse.button === Qt.LeftButton) {
            showSeconds = !showSeconds;
        } else if (mouse.button === Qt.RightButton) {
            runCal.running = true;
        }
    }

    Text {
        id: clockText
        anchors.centerIn: parent
        text: clockRoot.formatTime()
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 16
        font.weight: Font.Medium
        color: "#ffff7f"
    }
}
