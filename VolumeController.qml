import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

MouseArea {
    id: volumeRoot

    implicitWidth: mainVolumeRow.implicitWidth + 8
    implicitHeight: 24
    hoverEnabled: true

    property int currentVolumePercent: 50
    property bool isMuted: false

    // Asynchronous processor to fetch current audio metrics
    Process {
        id: audioQuery
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                let output = text.trim();
                if (output.length === 0) return;

                volumeRoot.isMuted = output.includes("[MUTED]");

                let match = output.match(/Volume:\s+([0-9.]+)/);
                // FIX: Check that the match array exists, then pull captured index [1]
                // instead of the full text block at index [0]!
                if (match && match[1]) {
                    volumeRoot.currentVolumePercent = Math.round(parseFloat(match[1]) * 100);
                }
            }
        }
    }

    // 1. The Magic Link: Activates PipeWire properties specifically inside this file
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    // 2. Process to handle input commands (volume change / mute)
    Process { id: runCommand }
    function execute(args) {
        runCommand.command = args;
        runCommand.running = true;
    }

    // 3. IPC Handler for your sxhkd hotkeys
    IpcHandler {
        target: "volume"

        function increase(): void {
            execute(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", "2%+"]);
        }

        function decrease(): void {
            execute(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "2%-"]);
        }

        function toggle(): void {
            execute(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        }
    }

    // Interactive Core: Rolling mouse wheel up/down modifies sound levels
    WheelHandler {
        id: volumeWheel
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (wheel) => {
            if (wheel.angleDelta.y !== 0) {
                let change = (wheel.angleDelta.y > 0) ? "2%+" : "2%-";

                // Dispatches execution directly to your default output channel
                Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", change]);

                visualizerPopupTimer.restart();
                audioQuery.running = true;
            }
        }
    }

    	acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
        	if (mouse.button === Qt.LeftButton) {
        		Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        		audioQuery.running = true;
    		}
    		if (mouse.button === Qt.RightButton) {
        		Quickshell.execDetached(["pavucontrol"]);
    		}
    	}

    // Dynamic State Refresh Clock Tracker:
    // Watches background multimedia key states (sxhkd commands) automatically
    Timer {
        interval: 350 // Sweep check audio state 3 times a second for snappy media key responses
        running: true
        repeat: true
        onTriggered: {
            audioQuery.running = true;
        }
    }

    Timer {
        id: visualizerPopupTimer
        interval: 1500
        running: false
        repeat: false
    }

    // ================= VISUAL PRESENTATION LAYER =================
    RowLayout {
        id: mainVolumeRow
        anchors.centerIn: parent
        spacing: 8

        Text {
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
            Layout.alignment: Qt.AlignVCenter

            text: {
                if (volumeRoot.isMuted) return "󰝟";
                if (volumeRoot.currentVolumePercent < 30) return "󰕿";
                if (volumeRoot.currentVolumePercent < 70) return "󰖀";
                return "󰕾";
            }
            color: volumeRoot.isMuted ? "#585b70" : "#89b4fa"
        }

        Text {
            text: volumeRoot.isMuted ? "MUTED" : volumeRoot.currentVolumePercent + "%"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            font.bold: true
            // color: "#cdd6f4"
            color: volumeRoot.isMuted ? "#ff007f" : "#cdd6f4"
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            id: visualProgressBarFrame
            implicitHeight: 4
            radius: 2
            color: "#313244"
            Layout.alignment: Qt.AlignVCenter

            implicitWidth: visualizerPopupTimer.running ? 60 : 0
            visible: implicitWidth > 0

            Behavior on implicitWidth {
                NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
            }

            Rectangle {
                width: Math.min(1.0, volumeRoot.currentVolumePercent / 100) * parent.width
                height: parent.height
                radius: 2
                color: "#89b4fa"
            }
        }
    }
}
