import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

Rectangle {
    id: root
    signal closeRequested()

    color: "#aaa398"
    property color ink: "#171717"
    property color muted: "#615b53"
    property color panel: "#f0ece4"
    property color dark: "#2a2925"

    property bool settingsOpen: false

    property var bandwidthChoices: [
        0, 56000, 64000, 72000, 84000, 97000, 114000, 133000,
        151000, 168000, 184000, 200000, 217000, 236000,
        254000, 287000, 311000
    ]

    Settings {
        id: scanSettings
        category: "handyScan"
        property int minimumSignal: 20
        property bool onlyPi: false
        property int minimumBandwidthHz: 0
    }

    function applySavedSettings() {
        scanController.setMinimumSignal(scanSettings.minimumSignal)
        scanController.setMinimumBandwidthHz(scanSettings.minimumBandwidthHz)
    }

    function changeMinimumSignal(delta) {
        if (scanController.scanning)
            return

        const v = Math.max(0, Math.min(80,
                    scanSettings.minimumSignal + delta))
        scanSettings.minimumSignal = v
        scanController.setMinimumSignal(v)
    }

    function bandwidthChoiceIndex() {
        const wanted = scanSettings.minimumBandwidthHz
        let nearest = 0
        let best = 999999999

        for (let i = 0; i < bandwidthChoices.length; ++i) {
            const d = Math.abs(bandwidthChoices[i] - wanted)
            if (d < best) {
                best = d
                nearest = i
            }
        }
        return nearest
    }

    function changeMinimumBandwidth(delta) {
        if (scanController.scanning)
            return

        let i = bandwidthChoiceIndex() + delta
        i = Math.max(0, Math.min(bandwidthChoices.length - 1, i))

        scanSettings.minimumBandwidthHz = bandwidthChoices[i]
        scanController.setMinimumBandwidthHz(scanSettings.minimumBandwidthHz)
    }

    function bandwidthSettingText() {
        return scanSettings.minimumBandwidthHz > 0
                ? Math.round(scanSettings.minimumBandwidthHz / 1000) + " kHz"
                : "AUS"
    }

    function visibleStationModel() {
        const source = scanController.stations
        const out = []

        for (let i = 0; i < source.length; ++i) {
            const station = source[i]
            const hasPi = station.pi && station.pi.length > 0

            if (scanSettings.onlyPi && !hasPi)
                continue

            out.push({
                "sourceIndex": i,
                "station": station
            })
        }

        return out
    }

    property var displayedStations: visibleStationModel()

    Component.onCompleted: applySavedSettings()

    function mhz(khz) {
        return (Number(khz) / 1000.0).toFixed(3) + " MHz"
    }

    function bw(hz) {
        return Number(hz) > 0 ? Math.round(Number(hz) / 1000) + " kHz" : "–"
    }

    function lowerLevel() {
        if (!scanController.scanning)
            scanController.setMinimumSignal(
                Math.max(0, Math.round(scanController.minimumSignal) - 1))
    }

    function raiseLevel() {
        if (!scanController.scanning)
            scanController.setMinimumSignal(
                Math.min(80, Math.round(scanController.minimumSignal) + 1))
    }

    MouseArea {
        id: inputShield
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        preventStealing: true

        onPressed: function(mouse) {
            mouse.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 7

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            radius: 13
            color: root.dark

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14

                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: 8
                    color: scanController.scanning ? "#7a5015" : "#45443f"

                    Text {
                        anchors.centerIn: parent
                        text: "S"
                        color: "white"
                        font.pixelSize: 23
                        font.bold: true
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "UKW-SCAN"
                    color: "white"
                    font.pixelSize: 25
                    font.bold: true
                }

                Text {
                    text: root.displayedStations.length + " Sender"
                    color: "#dedbd4"
                    font.pixelSize: 13
                    font.bold: true
                }
            }

            TapHandler {
                onTapped: root.settingsOpen = true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 106
            radius: 13
            color: root.panel
            border.width: 1
            border.color: "#817b72"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: scanController.scanning ? "Aktuelle Frequenz" : "Scan bereit"
                            color: root.muted
                            font.pixelSize: 13
                        }

                        Text {
                            text: scanController.scanning
                                  ? root.mhz(scanController.currentFrequencyKhz)
                                  : "87.500 – 108.000 MHz"
                            color: root.ink
                            font.family: "monospace"
                            font.pixelSize: 24
                            font.bold: true
                        }
                    }

                    Text {
                        text: scanController.progress + " %"
                        color: root.ink
                        font.pixelSize: 18
                        font.bold: true
                    }
                }

                ProgressBar {
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    value: scanController.progress
                }

                Text {
                    Layout.fillWidth: true
                    text: scanController.statusText
                    color: root.muted
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }
        }





        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 180
            radius: 13
            color: "#efebe3"
            border.width: 1
            border.color: "#858077"
            clip: true

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                model: root.displayedStations
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    property var station: modelData.station

                    width: list.width
                    height: 96
                    color: stationTap.pressed
                           ? "#d7d1c7"
                           : (index % 2 === 0 ? "#f4f1ea" : "#ebe7df")

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: "#d1cbc1"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 9

                        Rectangle {
                            Layout.preferredWidth: 84
                            Layout.preferredHeight: 54
                            radius: 9
                            color: "#e1ddd4"
                            border.width: 1
                            border.color: "#9e988e"

                            Column {
                                anchors.centerIn: parent
                                spacing: 1

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: (Number(station.frequencyKhz) / 1000).toFixed(3)
                                    color: root.ink
                                    font.family: "monospace"
                                    font.pixelSize: 18
                                    font.bold: true
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "MHz"
                                    color: root.muted
                                    font.pixelSize: 11
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    text: station.ps && station.ps.length > 0
                                          ? station.ps : "ohne PS"
                                    color: root.ink
                                    font.pixelSize: 18
                                    font.bold: station.ps && station.ps.length > 0
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: station.pi && station.pi.length > 0
                                          ? station.pi : "----"
                                    color: root.muted
                                    font.family: "monospace"
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: station.pty && station.pty.length > 0
                                      ? station.pty : "–"
                                color: root.muted
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: Number(station.signalLevel).toFixed(1) + " dBµV"
                                    color: root.ink
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                Text {
                                    text: "· BW " + root.bw(station.bandwidthHz)
                                    color: root.muted
                                    font.pixelSize: 13
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "ANTIPPEN"
                                    color: "#2d77b5"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                        }
                    }

                    TapHandler {
                        id: stationTap
                        enabled: !scanController.scanning

                        onTapped: {
                            if (!xdrClient.ready)
                                return

                            scanController.tuneStation(modelData.sourceIndex)
                            root.closeRequested()
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.displayedStations.length === 0
                    text: scanSettings.onlyPi
                              ? "Keine gespeicherten Sender mit PI"
                              : "Noch keine Sender in der Fundliste"
                    color: root.muted
                    font.pixelSize: 15
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.minimumHeight: 42
            Layout.preferredHeight: 42
            Layout.maximumHeight: 42
            spacing: 5

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.minimumHeight: 40
                Layout.preferredHeight: 40
                Layout.maximumHeight: 40
                radius: 8
                color: startTap.pressed ? "#256c39" : "#348e4d"
                border.width: 1
                border.color: "#4c7155"
                opacity: xdrClient.ready && !scanController.scanning ? 1.0 : 0.45

                Text {
                    anchors.centerIn: parent
                    text: scanController.scanning ? "SCAN..." : "START"
                    color: "white"
                    font.pixelSize: 12
                    font.bold: true
                }

                TapHandler {
                    id: startTap
                    enabled: xdrClient.ready && !scanController.scanning
                    onTapped: scanController.startScan()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.minimumHeight: 40
                Layout.preferredHeight: 40
                Layout.maximumHeight: 40
                radius: 8
                color: stopTap.pressed ? "#8f3932" : "#b5483e"
                border.width: 1
                border.color: "#7b3933"
                opacity: scanController.scanning ? 1.0 : 0.45

                Text {
                    anchors.centerIn: parent
                    text: "STOP"
                    color: "white"
                    font.pixelSize: 12
                    font.bold: true
                }

                TapHandler {
                    id: stopTap
                    enabled: scanController.scanning
                    onTapped: scanController.stopScan()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.minimumHeight: 40
                Layout.preferredHeight: 40
                Layout.maximumHeight: 40
                radius: 8
                color: clearTap.pressed ? "#68635d" : "#7e7971"
                border.width: 1
                border.color: "#5f5b55"
                opacity: (!scanController.scanning
                          && scanController.stationCount > 0) ? 1.0 : 0.45

                Text {
                    anchors.centerIn: parent
                    text: "LÖSCHEN"
                    color: "white"
                    font.pixelSize: 11
                    font.bold: true
                }

                TapHandler {
                    id: clearTap
                    enabled: !scanController.scanning
                             && scanController.stationCount > 0
                    onTapped: scanController.clearStations()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.minimumHeight: 40
                Layout.preferredHeight: 40
                Layout.maximumHeight: 40
                radius: 8
                color: backTap.pressed ? "#1f1f1c" : "#33332f"
                border.width: 1
                border.color: "#77756f"

                Text {
                    anchors.centerIn: parent
                    text: "ZURÜCK"
                    color: "white"
                    font.pixelSize: 12
                    font.bold: true
                }

                TapHandler {
                    id: backTap
                    onTapped: root.closeRequested()
                }
            }
        }
    }
    Rectangle {
        id: settingsPage
        anchors.fill: parent
        z: 100
        visible: root.settingsOpen
        color: "#aaa398"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            preventStealing: true
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                radius: 13
                color: root.dark

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16

                    Text {
                        Layout.fillWidth: true
                        text: "SCAN-EINSTELLUNGEN"
                        color: "white"
                        font.pixelSize: 21
                        font.bold: true
                    }

                    Text {
                        text: scanController.scanning ? "SCAN LÄUFT" : ""
                        color: "#e4c36b"
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 92
                radius: 13
                color: root.panel
                border.width: 1
                border.color: "#817b72"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Mindestpegel"
                            color: root.ink
                            font.pixelSize: 17
                            font.bold: true
                        }
                        Text {
                            text: "Nur Signale ab diesem Pegel prüfen"
                            color: root.muted
                            font.pixelSize: 12
                        }
                    }

                    Button {
                        text: "−"
                        enabled: !scanController.scanning
                        onClicked: root.changeMinimumSignal(-1)
                    }

                    Rectangle {
                        Layout.preferredWidth: 66
                        Layout.preferredHeight: 42
                        radius: 8
                        color: "#faf7f1"
                        border.width: 1
                        border.color: "#aaa399"
                        Text {
                            anchors.centerIn: parent
                            text: scanSettings.minimumSignal
                            color: root.ink
                            font.pixelSize: 19
                            font.bold: true
                        }
                    }

                    Button {
                        text: "+"
                        enabled: !scanController.scanning
                        onClicked: root.changeMinimumSignal(1)
                    }

                    Text {
                        text: "dBµV"
                        color: root.muted
                        font.pixelSize: 13
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 82
                radius: 13
                color: root.panel
                border.width: 1
                border.color: "#817b72"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Nur Sender mit PI anzeigen"
                            color: root.ink
                            font.pixelSize: 17
                            font.bold: true
                        }
                        Text {
                            text: "Sender ohne PI bleiben gespeichert"
                            color: root.muted
                            font.pixelSize: 12
                        }
                    }

                    Switch {
                        checked: scanSettings.onlyPi
                        onToggled: scanSettings.onlyPi = checked
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 102
                radius: 13
                color: root.panel
                border.width: 1
                border.color: "#817b72"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Mindest-Bandbreite"
                            color: root.ink
                            font.pixelSize: 17
                            font.bold: true
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Nur Sender ab dieser gemessenen BW speichern"
                            color: root.muted
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }

                    Button {
                        text: "−"
                        enabled: !scanController.scanning
                        onClicked: root.changeMinimumBandwidth(-1)
                    }

                    Rectangle {
                        Layout.preferredWidth: 88
                        Layout.preferredHeight: 42
                        radius: 8
                        color: "#faf7f1"
                        border.width: 1
                        border.color: "#aaa399"
                        Text {
                            anchors.centerIn: parent
                            text: root.bandwidthSettingText()
                            color: root.ink
                            font.pixelSize: 15
                            font.bold: true
                        }
                    }

                    Button {
                        text: "+"
                        enabled: !scanController.scanning
                        onClicked: root.changeMinimumBandwidth(1)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                radius: 13
                color: "#ece8e0"
                border.width: 1
                border.color: "#9d978d"

                Text {
                    anchors.fill: parent
                    anchors.margins: 12
                    text: "Speichern: Pegel ≥ "
                          + scanSettings.minimumSignal + " dBµV"
                          + (scanSettings.minimumBandwidthHz > 0
                             ? " · BW ≥ " + root.bandwidthSettingText()
                             : " · BW-Filter AUS")
                          + "\nAnzeige: "
                          + (scanSettings.onlyPi
                             ? "nur Sender mit PI"
                             : "alle gespeicherten Sender")
                    color: root.muted
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Item { Layout.fillHeight: true }

            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                text: "FERTIG"
                font.pixelSize: 16
                font.bold: true
                onClicked: root.settingsOpen = false
            }
        }
    }

}
