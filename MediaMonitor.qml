import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: mediaMonitor

    // Exposed data properties for your layout to bind to
    property string trackTitle: "No Media Playing"
    property string artistName: ""
    property string playbackStatus: "Stopped" // Playing, Paused, or Stopped

    // 1. Process to dynamically follow player metadata updates natively
    Process {
        id: metadataTracker
        command: ["playerctl", "metadata", "--follow", "--format", "{{status}}||{{title}}||{{artist}}"]
        running: true
        
        stdout: SplitParser {
            onRead: (data) => {
                if (!data) return;
                
                let line = data.toString().trim();
                let tokens = line.split("||");
                
                if (tokens.length >= 3) {
                    mediaMonitor.playbackStatus = tokens[0];
                    mediaMonitor.trackTitle = tokens[1] ? tokens[1] : "Unknown Title";
                    mediaMonitor.artistName = tokens[2] ? tokens[2] : "Unknown Artist";
                }
            }
        }
    }

    // 2. Fallback check: If playerctl stops completely when a media player closes
    Process {
        id: playerCheck
        command: ["playerctl", "status"]
        
        stdout: SplitParser {
            onRead: (data) => {
                if (!data || data.toString().trim() === "") {
                    mediaMonitor.playbackStatus = "Stopped";
                    mediaMonitor.trackTitle = "No Media Playing";
                    mediaMonitor.artistName = "";
                }
            }
        }
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: playerCheck.running = true
    }
}
