import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: diskMonitor
    
    // Percent usage integer for the layout bar
    property int usage: 0
    // Raw human-readable string text (e.g., "45G / 120G")
    property string textUsage: "0B / 0B"

    Process {
        id: diskProc
        // Queries the disk usage for the root mount point in human-readable gigabytes
        command: ["sh", "-c", "df -h / | grep /"]
        
        stdout: SplitParser {
            onRead: (data) => {
                if (!data) return;
                
                // Tokens: [Filesystem, Size, Used, Avail, Use%, MountedOn]
                let tokens = data.trim().split(/\s+/);
                if (tokens.length < 5) return;
                
                let totalStr = tokens[1];
                let usedStr = tokens[2];
                let percentStr = tokens[4].replace("%", "");
                
                let percentVal = parseInt(percentStr);
                if (!isNaN(percentVal)) {
                    diskMonitor.usage = percentVal;
                    diskMonitor.textUsage = usedStr + " / " + totalStr;
                }
            }
        }
    }

    Timer {
        interval: 10000 // Updates every 10 seconds since disk storage changes slowly
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: diskProc.running = true
    }
}
