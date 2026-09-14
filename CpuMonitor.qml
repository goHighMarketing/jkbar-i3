import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: cpuMonitor
    
    property int usage: 0
    property real lastCpuTotal: 0
    property real lastCpuIdle: 0

    // Process to pull the raw CPU line from kernel stats
    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        
        stdout: SplitParser {
            onRead: (data) => {
                if (!data) return;
                
                // Split the 'cpu  user nice system idle...' tokens
                let tokens = data.trim().split(/\s+/);
                if (tokens.length < 5) return;
                
                // Calculate Idle time (idle + iowait)
                let idle = parseInt(tokens[4]) + parseInt(tokens[5]);
                
                // Calculate Total active time across the first 7 fields
                let total = 0;
                for (let i = 1; i < 8; i++) {
                    total += parseInt(tokens[i]);
                }
                
                // Avoid calculating on the very first frame tick
                if (lastCpuTotal > 0) {
                    let totalDelta = total - lastCpuTotal;
                    let idleDelta = idle - lastCpuIdle;
                    
                    if (totalDelta > 0) {
                        // Usage % = 100 * (1 - idle_delta / total_delta)
                        cpuMonitor.usage = Math.round(100 * (1 - (idleDelta / totalDelta)));
                    }
                }
                
                // Cache the calculations for the next loop sequence
                lastCpuTotal = total;
                lastCpuIdle = idle;
            }
        }
    }

    // Explicit loop timer to trigger the shell process cleanly every 2 seconds
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: cpuProc.running = true
    }
}
