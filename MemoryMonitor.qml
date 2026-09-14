import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: memMonitor
    
    // Percent usage integer for the layout engine
    property int usage: 0
    // Raw human-readable string text (e.g., "4.2G / 15.6G")
    property string textUsage: "0B / 0B"

    Process {
        id: memProc
        command: ["sh", "-c", "free -m | grep Mem"]
        
        stdout: SplitParser {
            onRead: (data) => {
                if (!data) return;
                
                let tokens = data.trim().split(/\s+/);
                if (tokens.length < 3) return;
                
                let totalM = parseFloat(tokens[1]);
                let usedM = parseFloat(tokens[2]);
                
                if (totalM > 0) {
                    memMonitor.usage = Math.round((usedM / totalM) * 100);
                    
                    // Convert Megabytes into clean Gigabyte text readouts
                    let totalG = (totalM / 1024).toFixed(1);
                    let usedG = (usedM / 1024).toFixed(1);
                    memMonitor.textUsage = usedG + "G / " + totalG + "G";
                }
            }
        }
    }

    Timer {
        interval: 2500 // Updates every 2.5 seconds to stagger processor spikes
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: memProc.running = true
    }
}
