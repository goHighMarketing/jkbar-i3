import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: selectorRoot

    // Everything else flows down normally right into your properties:
    readonly property string rawWallpaperDir: "/home/toadwick/Pictures/wallhaven.cc"
    readonly property string wallpaperDirUrl: "file://" + rawWallpaperDir + "/"

    // ================= PUBLIC REFRESH HOOK =================
    // This allows shell.qml to cleanly tell the scanner to run
    function refreshList() {
        dirScanner.running = true;
    }
    // =======================================================

    // --- FOCUS & ESCAPE KEY DISMISSAL TRACKER ---
    // Tells the inner QML layout graph that it can accept keyboard inputs
    focus: true

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            // Safely targets the wrapping PopupWindow directly and closes it!
            if (selectorRoot.parent && selectorRoot.parent.hasOwnProperty("visible")) {
                selectorRoot.parent.visible = false;
            }
            event.accepted = true; // Stop the keystroke event from leaking to bspwm
         }
    }
    // ============================================

    function setWallpaper(fileName) {
        let fullPath = rawWallpaperDir + "/" + fileName;
        Quickshell.execDetached(["feh", "--bg-fill", fullPath]);
    }

    Process {
        id: dirScanner
        command: ["find", selectorRoot.rawWallpaperDir, "-maxdepth", "1", "-type", "f", "-regextype", "egrep", "-iregex", ".*\\.(png|jpg|jpeg|webp)"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                wallpaperModel.clear();
                let output = text.trim();
                if (output.length === 0) return;
                let lines = output.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let fullPath = lines[i];
                    let fileName = fullPath.substring(fullPath.lastIndexOf("/") + 1);
                    let cleanName = fileName.replace(/\.[^/.]+$/, "").replace(/[-_]/g, " ");
                    cleanName = cleanName.replace(/\b\w/g, c => c.toUpperCase());
                    wallpaperModel.append({ "name": cleanName, "fileName": fileName });
                }
            }
        }
    }

    ListModel { id: wallpaperModel }

    // Wrap your styling cleanly inside a nice panel container background
    Rectangle {
        anchors.fill: parent
        color: "#1e1e2e"
        border.color: "#313244"
        border.width: 1
        radius: 8
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8 // Give it some clean padding
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4

            Text {
                text: "Select Wallpaper"
                font.pixelSize: 12
                font.bold: true
                color: "#a6adc8"
                Layout.fillWidth: true
            }

            Rectangle {
                implicitWidth: 20
                implicitHeight: 20
                radius: 4
                color: refreshArea.containsMouse ? "#313244" : "transparent"
                Text { anchors.centerIn: parent; color: "#dedede"; font.family: "Twemoji Mozilla"; text: "🗘"; font.pixelSize: 10 }
                MouseArea {
                    id: refreshArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: dirScanner.running = true;
                }
            }
        }

        // Horizontal scrolling gallery (THE TRUE FLICKABLE CONTENTX FIX)
        ScrollView {
            id: galleryScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: rowItems.width

            ScrollBar.horizontal.policy: ScrollBar.AsNeeded
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            // ================= AUTO-SCROLL ENGINE BACKEND =================
            property string scrollDirection: "none"
            // Fine-tuned for standard pixel displacement steps per frame loop tick
           property real scrollStepPixelSize: 15.0

            Timer {
                id: autoScrollTimer
                interval: 16 // Silky smooth ~60fps pacing clock loop
                running: galleryScroll.scrollDirection !== "none"
                repeat: true
                onTriggered: {
                    // FIX: Target the internal Flickable canvas layer (contentItem) directly!
                    let currentPixelX = galleryScroll.contentItem.contentX;
                    let maxPixelX = Math.max(0, galleryScroll.contentWidth - galleryScroll.width);

                    if (galleryScroll.scrollDirection === "right") {
                        galleryScroll.contentItem.contentX = Math.min(maxPixelX, currentPixelX + galleryScroll.scrollStepPixelSize);
                    } else if (galleryScroll.scrollDirection === "left") {
                        galleryScroll.contentItem.contentX = Math.max(0, currentPixelX - galleryScroll.scrollStepPixelSize);
                    }
                }
            }
            // ==============================================================

            Text {
                visible: wallpaperModel.count === 0
                text: "No wallpapers found in\n" + selectorRoot.rawWallpaperDir
                font.pixelSize: 11
                color: "#7f849c"
                horizontalAlignment: Text.AlignHCenter
                anchors.centerIn: parent
            }

            // Keep your exact original wheel scrolling physics intact
            WheelHandler {
                id: wheelHandler
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y !== 0) {
                        let step = (wheel.angleDelta.y / 120) * 40;
                        galleryScroll.ScrollBar.horizontal.position = Math.max(0,
                            Math.min(1.0 - galleryScroll.ScrollBar.horizontal.size,
                                     galleryScroll.ScrollBar.horizontal.position - (step / galleryScroll.contentWidth))
                        );
                    }
                }
            }

            Row {
    id: rowItems
    spacing: 8
    height: parent.height

    Repeater {
        model: wallpaperModel
        delegate: Rectangle {
            id: thumbnailWrapper
            implicitWidth: 180
            implicitHeight: 130
            radius: 4
            color: "#181825"
            border.color: thumbnailMouseArea.containsMouse ? "#f5c2e7" : "transparent"
            border.width: 1.5
            clip: true // CRITICAL: This crops the zooming image so it doesn't bleed out of the card edges!

            ColumnLayout {
                anchors.fill: parent
                spacing: 1
                anchors.margins: 1

                // --- CROPPING LAYER FOR SMOOTH ZOOM ---
                // We wrap the image in a clipped Item so it doesn't overlap the text when expanding
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true 

                    Image {
                        id: wallpaperImg
                        anchors.fill: parent
                        source: selectorRoot.wallpaperDirUrl + model.fileName
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize.width: 180
                        sourceSize.height: 130

                        // Dynamic scale switch tied directly to the MouseArea's hover state
                        scale: thumbnailMouseArea.containsMouse ? 1.12 : 1.0
                        transformOrigin: Item.Center

                        // Animates the zoom back and forth smoothly over 180ms
                        Behavior on scale {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                Text {
                    text: model.name
                    font.pixelSize: 9
                    color: "#cdd6f4"
                    Layout.alignment: Qt.AlignHCenter
                    elide: Text.ElideRight
                    Layout.maximumWidth: parent.width - 4
                }
            }

            MouseArea {
                id: thumbnailMouseArea
                anchors.fill: parent
                hoverEnabled: true
                z: 1
                
                // onEntered is no longer strictly required for the zoom calculation,
                // as 'containsMouse' handles the state changes automatically!
                onEntered: {
                    // You can leave this empty or place hover sound effects / logging here
                }

                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        setWallpaper(model.fileName);
                    } else if (mouse.button === Qt.RightButton) {
                       let targetUrl = selectorRoot.wallpaperDirUrl + model.fileName;

                       if (typeof root.showPreviewPopup === "function") {
                           root.showPreviewPopup(targetUrl);
                       }
                   }
                }
            }
        }
    }
}


            // ================= VISUAL HOVER EDGE INTERCEPTORS =================
            // FIX: Instead of anchoring to dynamic bounds, we use explicit top-level window
            // viewport dimensions so they stay locked as absolute layout rails on the sides.
            MouseArea {
                id: leftScrollZone
                width: 50
                height: galleryScroll.height
                x: galleryScroll.contentItem.contentX // Syncs coordinate grid dynamically as the list shifts
                anchors.top: parent.top
                hoverEnabled: true
                z: 10

                onEntered: galleryScroll.scrollDirection = "left"
                onExited: galleryScroll.scrollDirection = "none"
            }

            MouseArea {
                id: rightScrollZone
                width: 50
                height: galleryScroll.height
                // Force position to stay anchored perfectly to the right frame edge at all times
                x: galleryScroll.contentItem.contentX + galleryScroll.availableWidth - 50
                anchors.top: parent.top
                hoverEnabled: true
                z: 10

                onEntered: galleryScroll.scrollDirection = "right"
                onExited: galleryScroll.scrollDirection = "none"
            }
            // ==================================================================
        }
    }
}
