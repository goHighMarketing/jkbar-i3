// Workspaces.qml
import QtQuick
import Quickshell
// Import Quickshell's native C++ i3 IPC tracking engine
import Quickshell.I3

QtObject {
    id: root

    // Exposes the native sorted array directly to your shell.qml Repeater model
    property var occupiedWorkspaces: {
        let sorted = [];
        // Map native I3.workspaces objects directly into the array structure
        let rawWorkspaces = I3.workspaces.values;
        
        for (let i = 0; i < rawWorkspaces.length; i++) {
            let item = rawWorkspaces[i];
            
            sorted.push({
                name: item.name.toString(),
                isFocused: item.focused === true,   // Native C++ focus property tracking
                isOccupied: item.active === true || item.focused === true,
                isUrgent: item.urgent === true      // Native C++ urgent property tracking
            });
        }
        
        // Sort numerically to prevent bar items from jumping around
        sorted.sort((a, b) => parseInt(a.name) - parseInt(b.name));
        return sorted;
    }

    // Retain an empty helper function to prevent click method crashes in shell.qml
    function refresh() {
        // No longer needed because Quickshell.I3 handles instant native updates!
    }
}
 