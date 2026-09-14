// Weather.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

RowLayout {
    id: weatherRoot
    spacing: 12

    property string weatherString: "wttr..." 
    
    ListModel {
        id: forecastModel
    }

    Timer {
        interval: 900000 
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchWeatherJson.running = true
    }

    Process {
        id: fetchWeatherJson
        command: ["curl", "-s", "wttr.in/?format=j1"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                let rawText = this.text.trim();
                if (rawText === "" || rawText.includes("Error")) {
                    weatherRoot.weatherString = "Weather Error";
                    return;
                }

                try {
                    let data = JSON.parse(rawText);
                    
                    // 1. Current condition bar text
                    let current = data.current_condition[0];
                    let tempF = current.temp_F; 
                    let currentDesc = current.weatherDesc[0].value;
                    let emoji = getWeatherEmoji(currentDesc);
                    weatherRoot.weatherString = emoji + " " + tempF + "°F";

                    // 2. Populate 3-day forecast model
                    forecastModel.clear();
                    let forecasts = data.weather; 
                    
                    for (let i = 0; i < Math.min(forecasts.length, 3); i++) {
                        let f = forecasts[i];
                        let dayName = getDayName(f.date);
                        if (i === 0) dayName = "Today";
                        
                        // Extract the raw text description at midday (12:00 PM is hourly[4])
                        let middayConditionText = f.hourly[4].weatherDesc[0].value;
                        
                        forecastModel.append({
                            day: dayName,
                            condition: getWeatherEmoji(middayConditionText),
                            desc: middayConditionText, // <--- Added textual description here!
                            tempMax: f.maxtempF + "°F", 
                            tempMin: f.mintempF + "°F"
                        });
                    }

                } catch (e) {
                    console.log("Error parsing weather JSON:", e);
                    weatherRoot.weatherString = "Parse Error";
                }
            }
        }
    }

    function getWeatherEmoji(desc) {
        desc = desc.toLowerCase();
        if (desc.includes("sunny") || desc.includes("clear")) return "☀️";
        if (desc.includes("partly cloudy")) return "⛅";
	if (desc.includes("haze")) return "⛅";
        if (desc.includes("cloudy") || desc.includes("overcast")) return "☁️";
        if (desc.includes("rain") || desc.includes("shower") || desc.includes("drizzle")) return "🌧️";
        if (desc.includes("patchy") && desc.includes("snow")) return "🌦️";
        if (desc.includes("thunder") || desc.includes("storm")) return "⛈️";
    if (desc.includes("patchy") && desc.includes("rain")) return "🌦️";
        if (desc.includes("snow") || desc.includes("ice") || desc.includes("flurry")) return "❄️";
        if (desc.includes("fog") || desc.includes("mist")) return "🌫️";
        return "🌤️";
    }

    function getDayName(dateString) {
        let parts = dateString.split('-');
        let date = new Date(parts[0], parts[1] - 1, parts[2]);
        return date.toLocaleDateString('en-US', { weekday: 'short' });
    }

    Text {
        id: weatherText
        text: weatherRoot.weatherString
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        font.weight: Font.Bold
        color: "#aaddff"  //  "#a9b1d6"
        Layout.alignment: Qt.AlignVCenter

        // INLINE COLOR EMOJI INJECTION (for full colour emojis)
        // wget -O ~/.local/share/fonts/TwemojiMozilla.ttf https://github.com/mozilla/twemoji-colr/releases/download/v0.7.0/Twemoji.Mozilla.ttf
        // clear cache:  fc-cache -fv
        Text {
            // Grabs ONLY the first character (the raw emoji glyph string)
            text: weatherRoot.weatherString.substring(0, 2)
            font.family: "Twemoji Mozilla"
            font.pixelSize: 14

            // This locks it cleanly to sit right in front of the main temperature block text
            anchors.left: parent.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
        }

        PopupWindow {
            id: weatherDropdown
            visible: hoverArea.containsMouse
            
            anchor {
                item: weatherText
                edges: Edges.Bottom
                gravity: Edges.Bottom
                margins { top: 5 }
            }

            // Expanded the width slightly to elegantly hold the word descriptions
            implicitWidth: 300
            implicitHeight: 95

            Rectangle {
                anchors.fill: parent
                color: "#1a1b26"
                border.color: "#3d59a1"
                border.width: 1
                radius: 8

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Repeater {
                        model: forecastModel
                        
                        delegate: Row {
                            spacing: 12
                            
                            // Day column
                            Text {
                                text: model.day
                                width: 45
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: model.day === "Today" ? "#ff007f" : "#7aa2f7"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                             // Emoji column (FIXED VIA VECTOR WEATHER GLYPHS)
                             Text {
                                 text: model.condition
                                 width: 24
                                 // font.family: "JetBrainsMono Nerd Font Mono"
                                 font.family: "Twemoji Mozilla"
                                 font.styleName: "Mono"
                                 font.pixelSize: 16
                                 color: "#b4befe" // Native vector color injection! No more black silhouettes.
                                 horizontalAlignment: Text.AlignHCenter
                                 anchors.verticalCenter: parent.verticalCenter
                             }
                            
                            // NEW: Midday Text Condition column (e.g., "Partly Cloudy")
                            Text {
                                text: model.desc
                                width: 110 // Gives enough layout width for text strings
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: "#9aa5ce" // Soft muted purple text
                                elide: Text.ElideRight // Protection against exceptionally long names
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            // Temperature column
                            Text {
                                text: model.tempMax + " | " + model.tempMin
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: "#9ece6a"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
