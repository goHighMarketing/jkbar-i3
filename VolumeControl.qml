import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

RowLayout {
    id: volumeRoot
    spacing: 6

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

    // 4. Interactive Volume Button & Scroll area
    MouseArea {
        implicitWidth: 70
        implicitHeight: 24
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        // Mouse scroll adjusts volume
        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) {
                execute(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", "2%+"]);
            } else {
                execute(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "2%-"]);
            }
        }

        // Left-click toggles mute
        onClicked: {
        if (mouse.button === Qt.LeftButton) {
                execute(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        } else if (mouse.button === Qt.RightButton) {
        Quickshell.execDetached(["pavucontrol"]);
        }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 6

            // Dynamic Icon
            Text {
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
                color: (!Pipewire.defaultAudioSink || !Pipewire.defaultAudioSink.audio || Pipewire.defaultAudioSink.audio.muted)
                                       ? "#ff007f"
                                       : "#55ffb0"
                Layout.alignment: Qt.AlignVCenter

                text: {
                    if (!Pipewire.defaultAudioSink || !Pipewire.defaultAudioSink.audio) {
                        return "󰝟";
                    }
                    if (Pipewire.defaultAudioSink.audio.muted) {
                        return "󰝟";
                    }
                    const vol = Pipewire.defaultAudioSink.audio.volume;
                    if (vol === 0) return "󰕿";
                    if (vol < 0.3) return "󰕿";
                    if (vol < 0.7) return "󰖀";
                    return "󰕾";
                }
            }

            // Dynamic Percentage Text
            Text {
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: (!Pipewire.defaultAudioSink || !Pipewire.defaultAudioSink.audio || Pipewire.defaultAudioSink.audio.muted)
                                       ? "#ff62a9"
                                       : "#ffffff"
                font.weight: Font.Medium
                Layout.alignment: Qt.AlignVCenter

                text: {
                    if (!Pipewire.defaultAudioSink || !Pipewire.defaultAudioSink.audio) {
                        return "0%";
                    }
                    if (Pipewire.defaultAudioSink.audio.muted) {
                        return "Muted";
                    }
                    const percent = Math.round(Pipewire.defaultAudioSink.audio.volume * 100);
                    return percent + "%";
                }
            }
        }
    }
}
