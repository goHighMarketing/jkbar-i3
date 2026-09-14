//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Uses "Twemoji Mozilla" fonts for full colour emojis, or use "JetBrainsMono Nerd Font"
// mkdir ~/.local/share/fonts
// wget -O ~/.local/share/fonts/TwemojiMozilla.ttf https://github.com/mozilla/twemoji-colr/releases/download/v0.7.0/Twemoji.Mozilla.ttf
// clear cache:  fc-cache -fv


ShellRoot {
    id: root

    // --- STATE VARIABLES ---
    property int activeWorkspace: 1
    property bool controlCenterOpen: false
    property bool isAppFullscreen: false
    property bool nightLightActive: false

    // --- PREVIEW SYSTEM VARIABLES ---
    property bool isPreviewOpen: false
    property string activePreviewUrl: ""

    function showPreviewPopup(imgUrl) {
        activePreviewUrl = imgUrl;
        isPreviewOpen = true;
    }

    // --- DATA FETCHING & PROCESSES ---

 
    // 2. i3 Fullscreen Tracker
    Process {
        id: i3FullscreenListener
        // Listens for window focus shifts or window property changes (like entering fullscreen)
        command: ["i3-msg", "-t", "subscribe", "['window']"]
        running: true

        stdout: SplitParser {
            onRead: (data) => {
                // Instantly trigger the secondary checker payload on window layout shifts
                i3CheckCurrentFullscreen.running = true;
            }
        }
    }

    // Secondary sub-process to evaluate focused window node layout masks safely
    Process {
        id: i3CheckCurrentFullscreen
        // Shell Script Trap: Queries the i3 tree, targets the focused node, and extracts fullscreen mode
        command: ["sh", "-c", "if i3-msg -t get_tree | grep -Po '\"focused\":true.*?\"fullscreen_mode\":\\K[0-1]' | grep -q '1'; then echo 'yes'; else echo 'no'; fi"]
        running: false

        stdout: SplitParser {
            onRead: (data) => {
                let response = data.toString().trim();

                if (response === "yes") {
                    root.isAppFullscreen = true;
                } else {
                    root.isAppFullscreen = false;
                }
            }
        }
    }



        // --- THE MAIN BAR PANEL ---
    PanelWindow {
        id: mainBar
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 40
        color: "#1e1e2e" // Catppuccin Mocha base

        // Bind visibility to the inverse of our fullscreen state! (Hide bar when apps are fullscreen.)
        visible: !root.isAppFullscreen

        margins {
            top: 0
            left: 3
            right: 3
            bottom: 0
        }

        // We use a plain Item container with explicit margins to prevent container overflow
        Item {
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 15

            // ================= LEFT: LAUNCHER & WORKSPACES =================
            Workspaces {
                id: wmState
            }

            Row {
                id: leftWorkspaceBar
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12 // Comfortable spacing between the launcher and workspace dots

                // ---    THE ROFI APP LAUNCHER BUTTON (WITH HOVER GLOW) ---
                Rectangle {
                    id: launcherBtn
                    width: 32
                    height: 28
                    radius: 6

                    // Core Background Accent: Shift from Sapphire to a vibrant neon Cyan on hover
                    color: launcherMouse.containsMouse ? "#94e2d5" : "#74c7ec"

                    // Smooth Color Interpolation Engine
                    Behavior on color {
                        ColorAnimation { duration: 200; easing.type: Easing.OutQuad }
                    }

                    // THE GLOW LAYER: An outer visual expansion ring that fades in smoothly
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3 // Expands slightly outside the boundaries of the main button
                        radius: 8
                        z: -1 // Renders safely beneath your text and main container button

                        // Use a highly translucent version of your accent color (#30 opacity hex mask)
                        color: "#3074c7ec"

                        // Instantly toggle visibility based on hover tracking
                        opacity: launcherMouse.containsMouse ? 1.0 : 0.0

                        // Smooth Fade Animation Track
                        Behavior on opacity {
                            NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        font.bold: true
                        color: "#11111b"
                    }

                    MouseArea {
                        id: launcherMouse
                        anchors.fill: parent
                        hoverEnabled: true // CRUCIAL: Tells the layout engine to listen for cursor position sweeps
                        // cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            root.controlCenterOpen = false;
                            Quickshell.execDetached([
                                "sh", "-c",
                                "rofi -show drun -modi drun -line-padding 4 -hide-scrollbar -show-icons -theme ~/.config/i3/rofi/config-jkbar.rasi"
                            ]);
                        }
                    }
                }

                LayoutSwitcher {
                    Layout.alignment: Qt.AlignVCenter
                }

                // WALLPAPER TRIGGER BUTTON
                Rectangle {
                    id: wallpaperButton
                    width: 24
                    height: 24
                    color: wallpaperMouse.containsMouse ? "#313244" : "transparent"
                    border.color: "white"
                    border.width: 1
                    radius: 4

                    Text {
                        anchors.centerIn: parent
                        text: "🖼️"
                        font.pixelSize: 12
                        font.family: "Twemoji Mozilla"
                        color: "#b4befe"
                    }

                    MouseArea {
                        id: wallpaperMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            // 1. Toggles our full-screen shield window state cleanly on click
                            wallpaperFullShield.visible = !wallpaperFullShield.visible;

                            // 2. FIXED: If the drawer just opened, tell our selector component to refresh!
                            if (wallpaperDrawerWindow.visible) {
                                // Reaches down inside the container rectangle to target your wallpaper selector instantly
                                wallpaperSelectorComponent.refreshList();
                            }
                        }
                    }
                }

                // --- X11 BULLETPROOF WALLPAPER DISMISSAL CONTAINER ---
                // Instead of a standalone popup, we spin up a full screen invisible layer
                PanelWindow {
                    id: wallpaperFullShield
                    visible: false

                    // Lock this panel to expand across the entire monitor canvas surface
                    anchors.top: true
                    anchors.bottom: true
                    anchors.left: true
                    anchors.right: true

                    // Force transparency so your terminal windows show through perfectly
                    color: "#00000000"

                    // Instructs i3 to completely ignore this frame layer for tiling allocation
                    exclusionMode: ExclusionMode.None

                    // ================= FULL SCREEN MOUSE SHIELD =================
                    // Clicking ANY empty workspace zone outside your selector box closes it instantly!
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            wallpaperFullShield.visible = false;
                        }
                    }
                    // ============================================================

                    // --- THE ACTUAL VISUAL WALLPAPER DRAWER RECTANGLE ---
                    // Nesting the visual geometry here maps it right back to your panel bar coordinates
                    Rectangle {
                        id: wallpaperDrawerWindow
                        width: 1850
                        height: 250
                        color: "transparent" // Let the selector component's theme color pass through

                        // Positioning calculations matching your exact old offsets
                        x: mainBar.x + (mainBar.width - 1850) - 20 // Adjust coordinates to align with your top button
                        y: 46

                        // Prevent pointer clicks inside the actual gallery card from triggering the shield close
                        MouseArea {
                            anchors.fill: parent
                            propagateComposedEvents: false
                            onClicked: (mouse) => mouse.accepted = true
                        }

                        WallpaperSelector {
                            id: wallpaperSelectorComponent
                            anchors.fill: parent
                        }
                    }
                }

                // --- X11 BULLETPROOF PREVIEW POPUP CONTAINER ---
                PanelWindow {
                    id: wallpaperPreviewShield
                    visible: root.isPreviewOpen

                    // Lock this panel to expand across the entire monitor canvas surface
                    anchors.top: true
                    anchors.bottom: true
                    anchors.left: true
                    anchors.right: true

                    // Force transparency so your wallpaper gallery remains beautifully visible behind it
                    color: "#00000000"
                    exclusionMode: ExclusionMode.None

                    // ================= FULL SCREEN MOUSE SHIELD =================
                    // Clicking ANY area outside the 1024x720 preview panel drops it out of view instantly!
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.isPreviewOpen = false;
                            root.activePreviewUrl = "";
                        }
                    }
                    // ============================================================

                    // --- THE ACTUAL VISUAL 1024x720 PREVIEW WINDOW ---
                    Rectangle {
                        width: 1024
                        height: 720
                        color: "#181825" // Catppuccin Mocha Crust
                        radius: 12

                        // Locks the large preview frame dead-center on your active monitor canvas
                        anchors.centerIn: parent

                        // Stop clicks inside the picture card from closing the panel accidentally
                        MouseArea {
                            anchors.fill: parent
                            propagateComposedEvents: false
                            onClicked: (mouse) => mouse.accepted = true
                        }

                        // Outer border accent path
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: "#313244"
                            border.width: 2
                            radius: 12
                            z: 2
                        }

                        // High-fidelity image layout viewport
                        Image {
                            anchors.fill: parent
                            anchors.margins: 4
                            source: root.activePreviewUrl
                            fillMode: Image.PreserveAspectFit // Preserves ratio gracefully inside the box limits
                            asynchronous: true
                            smooth: true
                        }

                        // Subtle metadata overlay tab at the bottom
                        Rectangle {
                            width: parent.width - 8
                            height: 35
                            color: "#11111b"
                            opacity: 0.85
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottomMargin: 4
                            radius: 8
                            z: 3

                            Text {
                                anchors.centerIn: parent
                                text: "Left-Click anywhere outside this preview to close"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: "#a6adc8"
                            }
                        }
                    }
                } // End of Preview Container Window

               // NATIVE QUICKSHELL POPUP WINDOW
                PopupWindow {
                    id: wallpaperPopup
                    visible: false

                    implicitWidth: 1850
                    implicitHeight: 250

                    // Connect the popup to the main bar window
                    anchor.window: mainBar

                    // POSITIONING MATRIX:
                    anchor.rect: wallpaperButton.mapToItem(mainBar.contentItem, -296, 40, wallpaperButton.width, wallpaperButton.height)

                    // Tells Quickshell to watch global pointer tracking hooks
                    grabFocus: true

                    // ================= CLICK DISMISSAL TRACKER =================
                    Connections {
                        target: wallpaperPopup

                        // Fires the millisecond you click outside the 1850x250 rectangle
                        // and focus shifts back to your terminal, browser, or i3 desktop background
                        function onActiveChanged() {
                            if (!wallpaperPopup.active) {
                                wallpaperPopup.visible = false;
                            }
                        }
                    }
                    // ===========================================================

                    WallpaperSelector {
                        anchors.fill: parent
                    }
                }

                // --- THE EXSTING REPEATER FOR WORKSPACES ---
                Row {
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: wmState.occupiedWorkspaces

                        delegate: Rectangle {
                            width: 28
                            height: 28
                            radius: 6
                            color: modelData.isFocused ? "#3d59a1" : "transparent"
                            // Smooth Color Interpolation Engine
                            Behavior on color {
                                ColorAnimation { duration: 200; easing.type: Easing.OutQuad }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                font.weight: modelData.isFocused ? Font.Bold : Font.Normal

                                color: {
                                    if (modelData.isUrgent) return "#f38ba8";
                                    if (modelData.isFocused) return "#ffffff"; 
                                    if (modelData.isOccupied) return "#7aa2f7"; 
                                    return "#565f89";
                                }
                            }

                            MouseArea {
				    id: wsMouse
				    anchors.fill: parent
				    hoverEnabled: true 
				    
				    onClicked: {
					// 1. Instantly update the desktop layout layer via the hardware bus
					Quickshell.execDetached(["i3-msg", "workspace", modelData.name])
					
					// 2. FIXED: Force the backend `Workspaces.qml` engine to refresh properties
					// This breaks the cache instantly so focus states turn bright white/blue
					if (wmState && typeof wmState.refresh === "function") {
					    wmState.refresh();
					}
				    }
				}
                            Rectangle { 
                                anchors.fill: parent
                                anchors.margins: -3 // Expands slightly outside the boundaries of the main button
                                radius: 8
                                z: -1 // Renders safely beneath your text and main container button

                                // Use a highly translucent version of your accent color (#30 opacity hex mask)
                                color: "#3074c7ec"

                                // Instantly toggle visibility based on hover tracking
                                opacity: wsMouse.containsMouse ? 1.0 : 0.0

                                // Smooth Fade Animation Track
                                Behavior on opacity {
                                    NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                                }
                            }
                        }
                    }
                    // THE GLOW LAYER: An outer visual expansion ring that fades in smoothly
                }
             } // End of Left Row


            // Optional: You can put your ActiveWindow title right next to the workspaces if you want
            ActiveWindow {
                anchors.left: leftWorkspaceBar.right
                anchors.leftMargin: 15
                anchors.verticalCenter: parent.verticalCenter
            }

            // ================= CENTER: CLOCK =================
            Clock {
                anchors.centerIn: parent
            }

            // ================= RIGHT: STATUS & CONTROLS =================
            // Row anchors straight to the right side, forcing perfect sequential layout order without overlapping
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 15

                Weather {
                   width: implicitWidth > 0 ? 66: implicitWidth
                   anchors.verticalCenter: parent.verticalCenter
                }

                NetworkTracker {
                    anchors.verticalCenter: parent.verticalCenter
                    // Default configuration uses "wlan0".
                    // Change this parameter line directly here if your primary connection is ethernet!
                    targetInterface: "eth0"
                }

                SysTempMonitor {
                     anchors.verticalCenter: parent.verticalCenter
                     // Tweak these variable parameters if your hardware registers on different zones!
                     cpuZoneIndex: "thermal_zone0"
                     gpuZoneIndex: "thermal_zone2"
                 }

            //    VolumeControl {
                  // anchors.right: parent.right
            //       anchors.verticalCenter: parent.verticalCenter
            //    }

                VolumeController {
                    Layout.alignment: Qt.AlignVCenter
                }

                SysTray {
                   anchors.verticalCenter: parent.verticalCenter
                   height: 28
               }


                // Control Center Trigger Button (WITH HOVER GLOW)
                Rectangle {
                    id: gearBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 35
                    height: 28
                    radius: 6

                    // State + Hover Color Matrix Mapping
                    color: root.controlCenterOpen ? "#f5c2e7" : (gearMouse.containsMouse ? "#45475a" : "#313244")

                    Behavior on color {
                        ColorAnimation { duration: 200; easing.type: Easing.OutQuad }
                    }

                    // THE GLOW LAYER: Translucent Mauve halo ring that wakes up on pointer sweep
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: 8
                        z: -1
                        color: "#30f5c2e7" // Translucent Catppuccin Mauve glow halo
                        opacity: gearMouse.containsMouse && !root.controlCenterOpen ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        font.family: "Twemoji Mozilla"
                        text: "⚙️"
                        color: root.controlCenterOpen ? "#11111b" : "#cdd6f4"
                    }

                    MouseArea {
                        id: gearMouse
                        anchors.fill: parent
                        hoverEnabled: true // Active tracking enabled
                        // cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (root.controlCenterOpen) {
                                root.controlCenterOpen = false;
                            } else {
                                root.controlCenterOpen = true;
                                if (root.controlCenterOpen) root.weatherDropdownOpen = false;
                            }
                        }
                    }
                }
            } // Closes the Status/Controls Row
        } // Closes the mainBar inner Item container
    } // Closes mainBar PanelWindow safely

    // --- THE CONTROL CENTER FLYOUT CONTAINER ---
    // Instead of a standalone floating block, we make this a full screen invisible shield
    // --- THE CONTROL CENTER FLYOUT CONTAINER ---
    PanelWindow {
            id: controlCenterOverlay
            visible: root.controlCenterOpen
/*
            anchors.top: true
            anchors.right: true
            implicitWidth: 680
            implicitHeight: 650
            color: "#181825" // Catppuccin Mocha Crust

            margins {
                top: 0
                right: 4
            }
*/
            // Lock this panel to cover the entire viewport surface
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            // FIX: The standard way to enforce alpha channels natively in Quickshell
            // #00 handles the transparency hex mask directly
            color: "#00000000"

            // Prevents i3 from creating tiling struts or borders around the sheet
            exclusionMode: ExclusionMode.None

            // ================= FULL SCREEN MOUSE SHIELD =================
            // Clicking this invisible background triggers an instant dismissal
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.controlCenterOpen = false;
                }
            }
            // ============================================================

            // --- THE ACTUAL VISUAL CONTROL CENTER RECTANGLE ---
            Rectangle {
                id: controlCenter
                width: 660
                height: 650
                color: "#181825" // Catppuccin Mocha Crust
                radius: 12

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 2
                anchors.rightMargin: 15
                anchors.leftMargin: 14

                // Prevent clicks inside the dashboard from passing through to the shield
                MouseArea {
                    anchors.fill: parent
                    propagateComposedEvents: false
                    onClicked: (mouse) => mouse.accepted = true
                }

                // Apply a single subtle border outline
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: "#313244"
                    border.width: 1
                    radius: 12
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

                    // ================= BACKEND TRACKER REGISTRATION =================
                    // Placing these invisible components here keeps them active in memory
                    // but safely removes them from the ColumnLayout visual calculation stream.
                    CpuMonitor { id: cpuStats }
                    MemoryMonitor { id: ramStats }
                    DiskMonitor { id: diskStats }
                    // =================================================================

                    // 1. Header Section (Now guaranteed to render first)
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Control Center"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 18
                            font.bold: true
                            color: "#cdd6f4"
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "JKBar - The Quickshell bar for i3"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: "#a6adc8"
                        }
                    }

                    BrightnessSlider {
                        Layout.fillWidth: false
                        Text {
                            text: "Brightness"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: "#a6adc8"
                        }
                    }

                    // 2. Quick Settings Grid (Toggles) (Now guaranteed to render second)
                    GridLayout {
                        columns: 2
                        rows: 2
                        columnSpacing: 12
                        rowSpacing: 12
                        Layout.fillWidth: true

                        // Volume Mute Button
                        Rectangle {
                            Layout.fillWidth: true
                            height: 50
                            radius: 8
                            color: muteMouse.containsMouse ? "#424355" : "#313244"

                            // Instantly toggle visibility based on hover tracking
                            opacity: muteMouse.containsMouse ? 0.9 : 1.0

                            // Smooth Fade Animation Track
                            Behavior on opacity {
                                NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "🔊 Mute Volume"
                                font.family: "JetBrainsMono Nerd Font"
                                color: "#cdd6f4"
                            }

                            MouseArea {
                                id: muteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    Quickshell.execDetached(["pamixer", "-t"]);
                                    if (typeof volPoll !== 'undefined') volPoll.running = true;
                                }
                            }
                        }

                        // DND / Fullscreen Toggle Override
                        Rectangle {
                            Layout.fillWidth: true
                            height: 50
                            radius: 8
                            color: root.isAppFullscreen ? "#f38ba8" : "#313244"
                            opacity: hideBarMouse.containsMouse ? 0.8 : 1.0

                            // Smooth Fade Animation Track
                            Behavior on opacity {
                                NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.isAppFullscreen ? "👁️ Bar: Hidden" : "👁️ Bar: Locked"
                                font.family: "JetBrainsMono Nerd Font"
                                color: root.isAppFullscreen ? "#11111b" : "#cdd6f4"
                            }

                            MouseArea {
                                id: hideBarMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.isAppFullscreen = !root.isAppFullscreen
                            }
                        }

                        // Night Light / Gamma Toggle
                        Rectangle {
                            Layout.fillWidth: true
                            height: 50
                            radius: 8
                            color: root.nightLightActive ? "#fab387" : "#313244"
                            opacity: nightlightMouse.containsMouse ? 0.8 : 1.0

                            // Smooth Fade Animation Track
                            Behavior on opacity {
                                NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.nightLightActive ? "🌙 Night Light: ON" : "🌙 Night Light: OFF"
                                font.family: "JetBrainsMono Nerd Font"
                                color: root.nightLightActive ? "#11111b" : "#cdd6f4"
                            }

                            MouseArea {
                                id: nightlightMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.nightLightActive = !root.nightLightActive;
                                    if (root.nightLightActive) {
                                        Quickshell.execDetached(["redshift", "-O", "4500k"]);
                                    } else {
                                        Quickshell.execDetached(["redshift", "-x"]);
                                    }
                                }
                            }
                        }

                        // Exit Session Button
                        Rectangle {
                            Layout.fillWidth: true
                            height: 50
                            radius: 8
                           // color: "#f38ba8"
                            color: exitSessionMouse.containsMouse ? "#ff007f" : "#f38ba8"

                            // Instantly toggle visibility based on hover tracking
                            opacity: exitSessionMouse.containsMouse ? 0.9 : 1.0

                            // Smooth Fade Animation Track
                            Behavior on opacity {
                                NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "🛑 Exit i3"
                                font.family: "JetBrainsMono Nerd Font"
                                font.bold: true
                                color: "#11111b"
                            }

                            MouseArea {
                                id: exitSessionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Quickshell.execDetached(["i3-msg", "exit"])
                            }
                        }
                    }

                    // 3. System Statistics Section (Now guaranteed to render third)
                    // System Statistics Section
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "System Resources"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: "#a6adc8"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#313244"
                        }

                        // --- ROW 1: CPU PROGRESS METER ---
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "💻 CPU"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: "#cdd6f4"
                                Layout.preferredWidth: 50
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 12
                                radius: 6
                                color: "#313244"

                                Rectangle {
                                    width: parent.width * (cpuStats.usage / 100)
                                    height: parent.height
                                    radius: 6
                                    color: cpuStats.usage > 80 ? "#f38ba8" : (cpuStats.usage > 50 ? "#f9e2af" : "#a6e3a1")

                                    Behavior on width {
                                        NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
                                    }
                                }
                            }

                            Text {
                                text: cpuStats.usage + "%"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: "#cdd6f4"
                                Layout.preferredWidth: 35
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                // --- ROW 2: RAM PROGRESS METER ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "🧠 RAM"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: "#cdd6f4"
                        Layout.preferredWidth: 50
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 12
                        radius: 6
                        color: "#313244"

                        Rectangle {
                            width: parent.width * (ramStats.usage / 100)
                            height: parent.height
                            radius: 6
                            color: ramStats.usage > 85 ? "#f38ba8" : (ramStats.usage > 65 ? "#f9e2af" : "#b4befe")

                            Behavior on width {
                                NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
                            }
                        }
                    }

                    Text {
                        text: ramStats.usage + "%"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: "#cdd6f4"
                        Layout.preferredWidth: 35
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // --- ROW 3: DISK PROGRESS METER ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "💾 DISK"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: "#cdd6f4"
                        Layout.preferredWidth: 50
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 12
                        radius: 6
                        color: "#313244"

                        Rectangle {
                            width: parent.width * (diskStats.usage / 100)
                            height: parent.height
                            radius: 6
                            color: diskStats.usage > 90 ? "#f38ba8" : (diskStats.usage > 75 ? "#f9e2af" : "#fab387")

                            Behavior on width {
                                NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
                            }
                        }
                    }

                    Text {
                        text: diskStats.usage + "%"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: "#cdd6f4"
                        Layout.preferredWidth: 35
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // Resource footprint subtitles mapping details
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 60
                    spacing: 20

                    Text {
                        text: "RAM footprint: " + ramStats.textUsage
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: "#a6adc8"
                    }

                    Text {
                        text: "Disk footprint: " + diskStats.textUsage
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: "#a6adc8"
                    }
                }

                // --- THE POWER MENU FLYOUT ROW ---
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Layout.topMargin: 8

                    Text {
                        text: "System Session"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: "#a6adc8"
                    }

                    // Visual separator line
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#313244"
                    }

                    // Horizontal Grid of Action Buttons
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        // 1. LOCK SYSTEM BUTTON
                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            radius: 8
                            color: lockMouse.containsMouse ? "#424355" : "#313244"

                            // Instantly toggle visibility based on hover tracking
                            opacity: lockMouse.containsMouse ? 0.9 : 1.0

                            // Smooth Fade Animation Track
                            Behavior on opacity {
                                NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "🔒 Lock"
                                font.family: "JetBrainsMono Nerd Font"
                                color: "#cdd6f4"
                            }

                            MouseArea {
                                id: lockMouse
                                anchors.fill: parent
                                // cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    root.controlCenterOpen = false;
                                    Quickshell.execDetached(["sh", "-c", "xset dpms force off && i3lock -c 11111b"]);
                                }
                            }
                        }

                        // 2. SUSPEND / SLEEP BUTTON
                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            radius: 8
                            color: sleepMouse.containsMouse ? "#424355" : "#313244"

                            // Instantly toggle visibility based on hover tracking
                            opacity: sleepMouse.containsMouse ? 0.9 : 1.0

                            // Smooth Fade Animation Track
                            Behavior on opacity {
                                NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "💤 Sleep"
                                font.family: "JetBrainsMono Nerd Font"
                                color: "#cdd6f4"
                            }

                            MouseArea {
                                id: sleepMouse
                                anchors.fill: parent
                                // cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    root.controlCenterOpen = false;
                                    Quickshell.execDetached(["systemctl", "suspend"]);
                                }
                            }
                        }

                        // 3. REBOOT BUTTON
                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            radius: 8
                            color: rebootMouse.containsMouse ? "#ff007f" : "#fab387"

                            // Instantly toggle visibility based on hover tracking
                            opacity: rebootMouse.containsMouse ? 0.9 : 1.0

                            // Smooth Fade Animation Track
                            Behavior on opacity {
                                NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "🔄 Reboot"
                                font.family: "JetBrainsMono Nerd Font"
                                color: "#11111b"
                                font.bold: true
                            }

                            MouseArea {
                                id: rebootMouse
                                anchors.fill: parent
                                // cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    root.controlCenterOpen = false;
                                    // Quickshell.execDetached(["systemctl", "reboot"]);
                                    Quickshell.execDetached(["sudo", "reboot"]); // sysVinit
				    // sudo visudo Then add: toadwick ALL=(ALL) NOPASSWD: /sbin/poweroff
                                }
                            }
                        }

                        // 4. SHUTDOWN BUTTON
                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            radius: 8
                            color: shutdownMouse.containsMouse ? "#ff007f" : "#f38ba8"

                            // Instantly toggle visibility based on hover tracking
                            opacity: shutdownMouse.containsMouse ? 0.9 : 1.0

                            // Smooth Fade Animation Track
                            Behavior on opacity {
                                NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "🛑 Off"
                                font.family: "JetBrainsMono Nerd Font"
                                color: "#11111b"
                                font.bold: true
                            }

                            MouseArea {
                                id: shutdownMouse
                                anchors.fill: parent
                                // cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    root.controlCenterOpen = false;
                                    // Quickshell.execDetached(["systemctl", "poweroff"]);
				    Quickshell.execDetached(["sudo", "poweroff"]) // sysVinit
				    // sudo visudo -> Then add: toadwick ALL=(ALL) NOPASSWD: /sbin/poweroff

                                } 
                            }
                        }
                    }
                } // End of Power Menu Row

                // FIXED BAR SEPARATOR: Pushes everything below to the absolute bottom of the container layout box
                Item {
                    Layout.fillHeight: true
                }

                // A clean, bottom-anchored close trigger with layout alignment separation
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 8
                    // color: "#1e1e2e"
                    border.color: "#313244"
                    border.width: 1
                    color: closepanelMouse.containsMouse ? "#424355" : "#313244"

                    // Instantly toggle visibility based on hover tracking
                    opacity: closepanelMouse.containsMouse ? 0.9 : 1.0

                    // Smooth Fade Animation Track
                    Behavior on opacity {
                        NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Close Panel"
                        font.family: "JetBrainsMono Nerd Font"
                        color: "#a6adc8"
                    }

                    MouseArea {
                        id: closepanelMouse
                        anchors.fill: parent
                        // cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.controlCenterOpen = false
                    }
                }
            } // Closes ColumnLayout
        } // Closes the root dashboard visual Rectangle
   }
}
