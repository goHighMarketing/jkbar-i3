import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

PanelWindow {
    id: overlayShield
    
    width: Screen.width
    height: Screen.height
    visible: false 
    focusable: true 

    color: "#8011111b" 

    // Full screen background mouse catcher—closes the overlay if clicking outside the band
    MouseArea {
	id: mhover
        anchors.fill: parent
        hoverEnabled: true
        focus: overlayShield.visible

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                overlayShield.visible = false;
            }
        }

        onClicked: overlayShield.visible = false;

        // The Interactive Horizontal Band
        Rectangle {
            id: thumbnailBand
            width: Math.min(1750, parent.width)
            height: 270
            anchors.centerIn: parent
            color: "#1e1e2e" 
            radius: 12
            border.color: "#313244"
            border.width: 1

            // 🟢 FIXED: This MouseArea only catches click-through events now,
            // preventing out-of-bounds clicks from shutting down the dashboard.
            // Hover tracking and scrolling are completely removed from this layer.
            MouseArea { 
                anchors.fill: parent 
                onClicked: (mouse) => { mouse.accepted = true; }
            }

            property var wallpaperList: []

            Process {
                id: readWallpaperDirectory
                running: overlayShield.visible 
                command: [
                    "sh", "-c",
                    "find \"$HOME/Pictures/wallhaven.cc\" -maxdepth 1 -type f \\( -iname \"*.jpg\" -o -iname \"*.jpeg\" -o -iname \"*.png\" -o -iname \"*.webp\" \\) | sort"
                ]

                property var tempAccumulator: []

                onRunningChanged: {
                    if (running) {
                        tempAccumulator = [];
                    } else {
                        thumbnailBand.wallpaperList = tempAccumulator;
                    }
                }

                stdout: SplitParser {
                    splitMarker: "\n"
                    onRead: (line) => {
                        let path = line.trim();
                        if (path !== "") {
                            let filename = path.substring(path.lastIndexOf('/') + 1);
                            readWallpaperDirectory.tempAccumulator.push({
                                filePath: path,
                                fileUrl: "file://" + path,
                                fileName: filename
                            });
                        }
                    }
                }
            }

            // Horizontal Grid/List Row Container
            ListView {
                id: thumbView
                anchors.fill: parent
                anchors.margins: modelMouse.containsMouse ? 0 : 20
                orientation: ListView.Horizontal
                spacing: 15
                model: thumbnailBand.wallpaperList
                
                // FIXED: Changing clip to false allows the transform matrix to overflow out of bounds!
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                MouseArea {
                    anchors.fill: parent
                    z: -1 
                    
                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y !== 0) {
                            if (wheel.angleDelta.y < 0) {
                                thumbView.flick(-1600, 0); // Kept your speed preference intact!
                            } else {
                                thumbView.flick(1600, 0); 
                            }
                            wheel.accepted = true;
                        }
                    }
                }

                delegate: Item {
                    id: delegateItem
                    width: 320 
                    height: 180
                    anchors.verticalCenter: parent.verticalCenter

                    // Elevate depth so the card renders above its left/right neighbors
                    z: modelMouse.containsMouse ? 10 : 1

                    // FIXED: Transform engine pushes magnification above the parent clipping plane layout
                    transform: Scale {
                        id: zoomTransform
                        origin.x: 160 // Center point anchors (320 / 2)
                        origin.y: 90  // Center point anchors (180 / 2)
                        
                        // Scale up to 1.5x magnification when hovered
                        xScale: modelMouse.containsMouse ? 1.5 : 1.0
                        yScale: modelMouse.containsMouse ? 1.5 : 1.0

                        Behavior on xScale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on yScale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: "#181825"
                        clip: true // Keep this true so the wallpaper stays rounded inside the card container!
                        
                        border.color: modelMouse.containsMouse ? "#f9e2af" : "#313244" 
                        border.width: modelMouse.containsMouse ? 2 : 1

                        Image {
                            anchors.fill: parent
                            source: modelData.fileUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true 
                        }
                    }

                    MouseArea {
                        id: modelMouse
                        anchors.fill: parent
                        hoverEnabled: true 
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                Quickshell.execDetached(["feh", "--bg-fill", modelData.filePath]);
                                overlayShield.visible = false; 
                            } else if (mouse.button === Qt.RightButton) {
                              //  Quickshell.execDetached(["feh", "-g", "1024x720", modelData.filePath]);
                            }
                        }
                    }
                }
            }
        }
    }
}
