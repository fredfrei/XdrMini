import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

Rectangle {
    id: tmcPage
    signal closeRequested()

    color: "#aaa398"

    property color panelTop: "#f4f1ea"
    property color panelBottom: "#ded8ce"
    property color ink: "#171717"
    property color mutedInk: "#615b53"
    property color darkPanel: "#2a2925"
    property color green: "#218b3a"
    property int radiusKm: tmcSettings.radiusKm
    property bool distanceFilterEnabled: true
    property string clockText: Qt.formatTime(new Date(), "hh:mm")

    Settings {
        id: tmcSettings
        category: "handyTmc"
        property int radiusKm: 100
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: tmcPage.clockText = Qt.formatTime(new Date(), "hh:mm")
    }

    function messageBlocks(fullText) {
        if (!fullText || fullText.length === 0)
            return []

        const source = fullText.split(/\n\s*\n/)
        const out = []
        for (let i = 0; i < source.length; ++i) {
            const b = source[i].trim()
            if (b.length > 0)
                out.push(b)
        }
        return out
    }

    function haversineKm(lat1, lon1, lat2, lon2) {
        const r = 6371.0088
        const rad = Math.PI / 180.0
        const p1 = lat1 * rad
        const p2 = lat2 * rad
        const dp = (lat2 - lat1) * rad
        const dl = (lon2 - lon1) * rad

        const a = Math.sin(dp / 2) * Math.sin(dp / 2)
                + Math.cos(p1) * Math.cos(p2)
                  * Math.sin(dl / 2) * Math.sin(dl / 2)

        return r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    }

    function blockDistanceKm(block, lat, lon) {
        if (!locationBridge.valid || !block || block.length === 0)
            return -1

        const rx = /\|\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)/g
        let match
        let minimum = -1

        while ((match = rx.exec(block)) !== null) {
            const bLat = Number(match[1])
            const bLon = Number(match[2])

            if (!isFinite(bLat) || !isFinite(bLon)
                    || bLat < -90 || bLat > 90
                    || bLon < -180 || bLon > 180)
                continue

            const d = haversineKm(lat, lon, bLat, bLon)
            if (minimum < 0 || d < minimum)
                minimum = d
        }

        return minimum
    }

    function locationName(line) {
        const colon = line.indexOf(":")
        if (colon < 0)
            return ""

        const parts = line.substring(colon + 1).trim().split("|")
        const road = parts.length > 0 ? parts[0].trim() : ""

        for (let i = 1; i < parts.length; ++i) {
            const candidate = parts[i].trim()
            if (candidate.length === 0)
                continue
            if (/^-?\d+[\.,]\d+\s*,\s*-?\d+[\.,]\d+$/.test(candidate))
                continue
            if (candidate === road)
                continue
            return candidate
        }
        return ""
    }

    function compactMessage(block) {
        const lines = block.split("\n")
        const out = []
        let startName = ""
        let endName = ""

        for (let i = 0; i < lines.length; ++i) {
            const t = lines[i].trim()
            if (t.indexOf("Start:") === 0)
                startName = locationName(t)
            else if (t.indexOf("Ende :") === 0 || t.indexOf("Ende:") === 0)
                endName = locationName(t)
        }

        for (let i = 0; i < lines.length; ++i) {
            let t = lines[i].trim()
            if (t.length === 0)
                continue

            if (i === 0) {
                out.push(t)
                continue
            }

            if (t.indexOf("TMC-MULTI:") === 0
                    || /^Event\s+\d+\s+Location\s+\d+/.test(t)
                    || t.indexOf("Rohwert:") === 0
                    || t === "Optional:"
                    || t.indexOf("- Separator") === 0
                    || t.indexOf("- Steuerung: Richtung umkehren") === 0
                    || t.indexOf("Richtung:") === 0)
                continue

            if (t.indexOf("Dauer/Persistenz: keine explizite Dauer") === 0
                    || t === "Umleitung: nein")
                continue

            if (t.indexOf("Ort (LTN 1):") === 0) {
                let value = t.substring("Ort (LTN 1):".length).trim()
                const pipe = value.indexOf("|")
                if (pipe >= 0)
                    value = value.substring(0, pipe).trim()
                if (value.length > 0)
                    out.push("Straße: " + value)
                continue
            }

            if (t.indexOf("Start:") === 0 || t.indexOf("Ende :") === 0
                    || t.indexOf("Ende:") === 0)
                continue

            if (t.indexOf("Abschnitt:") === 0) {
                if (startName.length > 0 && endName.length > 0)
                    out.push("Abschnitt: " + startName + " → " + endName)
                else
                    out.push(t.replace(/\s+\((positive|negative) LCL-Richtung\)$/, ""))
                continue
            }

            if (t.indexOf("- Zusatzereignis:") === 0) {
                let value = t.substring("- Zusatzereignis:".length).trim()
                value = value.replace(/^\d+\s*-\s*/, "")
                out.push("Zusätzlich: " + value)
                continue
            }

            if (t.indexOf("- Zusatzinformation:") === 0) {
                let value = t.substring("- Zusatzinformation:".length).trim()
                value = value.replace(/\s*\(Code \d+\)$/, "")
                out.push("Hinweis: " + value)
                continue
            }

            if (t.indexOf("- Dauer/Persistenz:") === 0) {
                const value = t.substring("- Dauer/Persistenz:".length).trim()
                if (value.indexOf("Typ L") >= 0)
                    out.push("Dauer: länger andauernd")
                else if (value.indexOf("Typ D") >= 0)
                    out.push("Dauer: dynamisch")
                else
                    out.push("Dauer: " + value)
                continue
            }

            if (t.indexOf("- Steuerung: Umleitung empfohlen/vorhanden") === 0) {
                out.push("Umleitung: empfohlen")
                continue
            }

            out.push(t)
        }

        return out.join("\n")
    }

    function lineValue(lines, prefix) {
        for (let i = 0; i < lines.length; ++i) {
            const t = lines[i].trim()
            if (t.indexOf(prefix) === 0)
                return t.substring(prefix.length).trim()
        }
        return ""
    }

    function cardFromBlock(block, distance) {
        const compact = compactMessage(block)
        const lines = compact.split("\n")
        const headline = lines.length > 0 ? lines[0].trim() : "Verkehrsmeldung"

        let road = lineValue(lines, "Straße:")
        let section = lineValue(lines, "Abschnitt:")
        const details = []

        for (let i = 1; i < lines.length; ++i) {
            const t = lines[i].trim()
            if (t.length === 0
                    || t.indexOf("Straße:") === 0
                    || t.indexOf("Abschnitt:") === 0)
                continue
            if (details.length < 2)
                details.push(t)
        }

        if (road.length === 0) {
            const m = compact.match(/\b(A\d+|B\d+|L\d+)\b/)
            road = m ? m[1] : "TMC"
        }

        if (section.length === 0)
            section = "Aktuelle Verkehrsmeldung"

        return {
            "road": road,
            "headline": headline,
            "section": section,
            "detail": details.join(" · "),
            "distance": distance
        }
    }

    function buildMessages(fullText, lat, lon, radius, filterEnabled) {
        const blocks = messageBlocks(fullText)
        const out = []

        for (let i = 0; i < blocks.length; ++i) {
            const d = blockDistanceKm(blocks[i], lat, lon)

            if (filterEnabled && locationBridge.valid) {
                if (d < 0 || d > radius)
                    continue
            }

            out.push(cardFromBlock(blocks[i], d))
        }

        if (locationBridge.valid) {
            out.sort(function(a, b) {
                if (a.distance < 0 && b.distance < 0)
                    return 0
                if (a.distance < 0)
                    return 1
                if (b.distance < 0)
                    return -1
                return a.distance - b.distance
            })
        }

        return out
    }

    property var displayedMessages: buildMessages(
        xdrClient.tmcMessagesText,
        locationBridge.latitude,
        locationBridge.longitude,
        radiusKm,
        distanceFilterEnabled)

    function gpsText() {
        if (!locationBridge.valid)
            return locationBridge.statusText

        let t = locationBridge.latitude.toFixed(5)
                + "°, "
                + locationBridge.longitude.toFixed(5) + "°"

        if (locationBridge.horizontalAccuracy > 0)
            t += "   ±" + Math.round(locationBridge.horizontalAccuracy) + " m"

        return t
    }

    function roadBadgeColor(road) {
        if (road && road.charAt(0) === "B")
            return "#e2aa16"
        if (road && road.charAt(0) === "L")
            return "#77736d"
        return "#2778b5"
    }

    function countText() {
        if (distanceFilterEnabled && locationBridge.valid)
            return displayedMessages.length + " Meldungen innerhalb "
                    + radiusKm + " km"
        if (locationBridge.valid)
            return displayedMessages.length + " aktuelle Meldungen"
        return displayedMessages.length + " Meldungen · GPS wird ermittelt"
    }

    Component.onCompleted: locationBridge.start()
    Component.onDestruction: locationBridge.stop()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 7

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            radius: 13
            color: tmcPage.darkPanel
            border.width: 1
            border.color: "#5b5953"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: 8
                    color: "#45443f"
                    border.width: 1
                    border.color: "#77736c"

                    Text {
                        anchors.centerIn: parent
                        text: "!"
                        color: "white"
                        font.pixelSize: 26
                        font.bold: true
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "TMC / Verkehr"
                    color: "white"
                    font.pixelSize: 25
                    font.bold: true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 82
            radius: 13
            border.width: 1
            border.color: "#7b756c"

            gradient: Gradient {
                GradientStop { position: 0.0; color: tmcPage.panelTop }
                GradientStop { position: 1.0; color: tmcPage.panelBottom }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12

                Column {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: "Sender"
                        color: tmcPage.mutedInk
                        font.pixelSize: 13
                    }
                    Text {
                        text: xdrClient.psText.length > 0 ? xdrClient.psText : "–"
                        color: tmcPage.ink
                        font.pixelSize: 24
                        font.bold: true
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    color: "#938d84"
                }

                Column {
                    Layout.fillWidth: true
                    Layout.leftMargin: 18
                    spacing: 3

                    Text {
                        text: "PI"
                        color: tmcPage.mutedInk
                        font.pixelSize: 13
                    }
                    Text {
                        text: xdrClient.piCode.length > 0 ? xdrClient.piCode : "----"
                        color: tmcPage.ink
                        font.family: "monospace"
                        font.pixelSize: 24
                        font.bold: true
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 118
            radius: 13
            border.width: 1
            border.color: "#7b756c"

            gradient: Gradient {
                GradientStop { position: 0.0; color: tmcPage.panelTop }
                GradientStop { position: 1.0; color: tmcPage.panelBottom }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 54
                    Layout.preferredHeight: 54
                    radius: 27
                    color: locationBridge.valid ? "#daf0dd" : "#e3e0d9"
                    border.width: 3
                    border.color: locationBridge.valid ? tmcPage.green : "#77736d"

                    Rectangle {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        radius: 7
                        color: locationBridge.valid ? tmcPage.green : "#77736d"
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        text: "Standort (GPS)"
                        color: "#2c6389"
                        font.pixelSize: 17
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: locationBridge.valid
                              ? "Aktueller Standort vom Handy"
                              : "Standort wird ermittelt"
                        color: locationBridge.valid ? tmcPage.green : tmcPage.mutedInk
                        font.pixelSize: 15
                        font.bold: locationBridge.valid
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: tmcPage.gpsText()
                        color: tmcPage.ink
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 112
                    Layout.preferredHeight: 52
                    radius: 11
                    color: refreshMouse.pressed ? "#cec8be" : "#e8e4dc"
                    border.width: 1
                    border.color: "#a49e94"

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 10
                        text: "AKTUALISIEREN"
                        color: tmcPage.ink
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        onClicked: locationBridge.requestUpdate()
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 82
            radius: 13
            border.width: 1
            border.color: "#7b756c"

            gradient: Gradient {
                GradientStop { position: 0.0; color: tmcPage.panelTop }
                GradientStop { position: 1.0; color: tmcPage.panelBottom }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: "Umkreis"
                    color: tmcPage.ink
                    font.pixelSize: 18
                    font.bold: true
                }

                SpinBox {
                    id: radiusBox
                    Layout.preferredWidth: 105
                    from: 10
                    to: 500
                    stepSize: 10
                    value: tmcSettings.radiusKm
                    editable: true

                    onValueModified: {
                        tmcSettings.radiusKm = value
                        tmcPage.radiusKm = value
                    }
                }

                Text {
                    text: "km"
                    color: tmcPage.ink
                    font.pixelSize: 16
                }

                Item { Layout.fillWidth: true }

                CheckBox {
                    text: "Filter aktiv"
                    checked: tmcPage.distanceFilterEnabled
                    onToggled: tmcPage.distanceFilterEnabled = checked
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: 10
            color: "#ece8e0"
            border.width: 1
            border.color: "#9d978d"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12

                Text {
                    Layout.fillWidth: true
                    text: tmcPage.countText()
                    color: tmcPage.mutedInk
                    font.pixelSize: 14
                }
                Text {
                    text: "Stand " + tmcPage.clockText
                    color: tmcPage.mutedInk
                    font.pixelSize: 13
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 13
            color: "#efebe3"
            border.width: 1
            border.color: "#858077"
            clip: true

            ListView {
                id: messageList
                anchors.fill: parent
                clip: true
                model: tmcPage.displayedMessages
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: messageList.width
                    height: Math.max(116, cardContent.implicitHeight + 22)
                    color: index % 2 === 0 ? "#f4f1ea" : "#ebe7df"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: "#d1cbc1"
                    }

                    RowLayout {
                        id: cardContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 11
                        spacing: 9

                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 20
                            color: "#fff5df"
                            border.width: 3
                            border.color: "#d84637"

                            Text {
                                anchors.centerIn: parent
                                text: "!"
                                color: "#242424"
                                font.pixelSize: 24
                                font.bold: true
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 62
                            Layout.preferredHeight: 38
                            radius: 8
                            color: tmcPage.roadBadgeColor(modelData.road)

                            Text {
                                anchors.centerIn: parent
                                text: modelData.road
                                color: "white"
                                font.pixelSize: 18
                                font.bold: true
                                fontSizeMode: Text.Fit
                                minimumPixelSize: 11
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: modelData.headline
                                color: tmcPage.ink
                                font.pixelSize: 17
                                font.bold: true
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.section
                                color: tmcPage.ink
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: modelData.detail.length > 0
                                text: modelData.detail
                                color: tmcPage.mutedInk
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignTop
                            visible: modelData.distance >= 0
                            text: modelData.distance.toFixed(0) + " km"
                            color: tmcPage.ink
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }
                }

                footer: Item {
                    width: messageList.width
                    height: tmcPage.displayedMessages.length === 0 ? 120 : 10

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 30
                        visible: tmcPage.displayedMessages.length === 0
                        text: {
                            if (!xdrClient.tmcMessagesText
                                    || xdrClient.tmcMessagesText.length === 0)
                                return "Noch keine aktuelle TMC-Meldung empfangen."
                            if (tmcPage.distanceFilterEnabled
                                    && locationBridge.valid)
                                return "Keine TMC-Meldung im eingestellten Umkreis."
                            return "Keine Meldung verfügbar."
                        }
                        color: tmcPage.mutedInk
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.pixelSize: 15
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 62
            radius: 13
            color: backMouse.pressed ? "#1f1f1c" : "#33332f"
            border.width: 2
            border.color: "#77756f"

            Text {
                anchors.centerIn: parent
                text: "ZURÜCK"
                color: "white"
                font.pixelSize: 21
                font.bold: true
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                onClicked: tmcPage.closeRequested()
            }
        }
    }
}
