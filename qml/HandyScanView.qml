import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    signal closeRequested()

    color: "#aaa398"
    property color ink: "#171717"
    property color muted: "#615b53"
    property color panel: "#f0ece4"
    property color dark: "#2a2925"

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
                    text: scanController.stationCount + " Sender"
                    color: "#dedbd4"
                    font.pixelSize: 13
                    font.bold: true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
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
            Layout.preferredHeight: 82
            radius: 13
            color: root.panel
            border.width: 1
            border.color: "#817b72"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: "Mindestpegel"
                    color: root.ink
                    font.pixelSize: 17
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "−"
                    font.pixelSize: 24
                    enabled: !scanController.scanning
                    onClicked: root.lowerLevel()
                }

                Rectangle {
                    Layout.preferredWidth: 70
                    Layout.preferredHeight: 46
                    radius: 8
                    color: "#faf7f1"
                    border.width: 1
                    border.color: "#aaa399"

                    Text {
                        anchors.centerIn: parent
                        text: Math.round(scanController.minimumSignal)
                        color: root.ink
                        font.pixelSize: 20
                        font.bold: true
                    }
                }

                Button {
                    text: "+"
                    font.pixelSize: 22
                    enabled: !scanController.scanning
                    onClicked: root.raiseLevel()
                }

                Text {
                    text: "dBµV"
                    color: root.muted
                    font.pixelSize: 14
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            spacing: 7

            Button {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: scanController.scanning ? "SCAN LÄUFT" : "SCAN START"
                enabled: xdrClient.ready && !scanController.scanning
                font.bold: true
                onClicked: scanController.startScan()
            }

            Button {
                Layout.preferredWidth: 105
                Layout.fillHeight: true
                text: "STOP"
                enabled: scanController.scanning
                font.bold: true
                onClicked: scanController.stopScan()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
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
                    text: scanController.stationCount + " Sender gespeichert"
                    color: root.muted
                    font.pixelSize: 14
                }

                Text {
                    text: scanController.newStationsThisScan + " neu"
                    color: scanController.newStationsThisScan > 0 ? "#218b3a" : root.muted
                    font.pixelSize: 14
                    font.bold: true
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
                id: list
                anchors.fill: parent
                clip: true
                model: scanController.stations
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    required property int index
                    required property var modelData

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
                                    text: (Number(modelData.frequencyKhz) / 1000).toFixed(3)
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
                                    text: modelData.ps && modelData.ps.length > 0
                                          ? modelData.ps : "ohne PS"
                                    color: root.ink
                                    font.pixelSize: 18
                                    font.bold: modelData.ps && modelData.ps.length > 0
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: modelData.pi && modelData.pi.length > 0
                                          ? modelData.pi : "----"
                                    color: root.muted
                                    font.family: "monospace"
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.pty && modelData.pty.length > 0
                                      ? modelData.pty : "–"
                                color: root.muted
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: Number(modelData.signalLevel).toFixed(1) + " dBµV"
                                    color: root.ink
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                Text {
                                    text: "· BW " + root.bw(modelData.bandwidthHz)
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

                            scanController.tuneStation(index)
                            root.closeRequested()
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: scanController.stationCount === 0
                    text: "Noch keine Sender in der Fundliste"
                    color: root.muted
                    font.pixelSize: 15
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            spacing: 7

            Button {
                Layout.preferredWidth: 135
                Layout.fillHeight: true
                text: "LISTE LÖSCHEN"
                enabled: !scanController.scanning && scanController.stationCount > 0
                font.bold: true
                onClicked: scanController.clearStations()
            }

            Button {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: "ZURÜCK"
                font.pixelSize: 18
                font.bold: true
                onClicked: root.closeRequested()
            }
        }
    }
}
