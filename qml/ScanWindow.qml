import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: root
    width: 920
    height: 580
    minimumWidth: 760
    minimumHeight: 420
    visible: false
    title: "XdrMini · Band-Scan"

    property var controller
    property var client
    property color aluminiumLight: "#eeeeea"
    property color aluminiumMid: "#c9c9c3"
    property color ink: "#262620"
    property color mutedInk: "#686861"
    property bool hideWithoutPi: false
    property var scanBandwidthValues: [0, 56000, 64000, 72000, 84000,
                                       97000, 114000, 133000, 151000,
                                       168000, 184000, 200000, 217000,
                                       236000, 254000, 287000, 311000]

    color: aluminiumLight

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "UKW-SCAN"
                color: root.ink
                font.pixelSize: 22
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Label {
                text: controller
                      ? controller.stationCount + " Sender · "
                        + controller.newStationsThisScan + " neu"
                      : "0 Sender"
                color: root.mutedInk
                font.pixelSize: 12
                font.bold: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 94
            radius: 4
            color: root.aluminiumMid
            border.width: 1
            border.color: "#85857f"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: controller && controller.scanning
                              ? (controller.currentFrequencyKhz / 1000).toFixed(3) + " MHz"
                              : "Bereit"
                        color: root.ink
                        font.family: "monospace"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: controller
                              ? "Durchlauf " + controller.currentPass
                                + "/" + controller.repeatCount
                                + " · " + controller.progress + " %"
                              : "0 %"
                        color: root.ink
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                ProgressBar {
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    value: controller ? controller.progress : 0
                }

                Label {
                    Layout.fillWidth: true
                    text: controller ? controller.statusText : "ScanController nicht verfügbar"
                    color: root.mutedInk
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label { text: "Mindestpegel:"; color: root.ink }
            SpinBox {
                from: 0
                to: 80
                editable: true
                value: controller ? Math.round(controller.minimumSignal) : 20
                enabled: controller && !controller.scanning
                onValueModified: if (controller) controller.setMinimumSignal(value)
            }
            Label { text: "dBµV"; color: root.mutedInk }

            Label { text: "Mindest-BW:"; color: root.ink }
            ComboBox {
                id: scanBandwidthBox
                Layout.preferredWidth: 125
                model: ["Aus", "56 kHz", "64 kHz", "72 kHz", "84 kHz",
                        "97 kHz", "114 kHz", "133 kHz", "151 kHz",
                        "168 kHz", "184 kHz", "200 kHz", "217 kHz",
                        "236 kHz", "254 kHz", "287 kHz", "311 kHz"]
                currentIndex: controller
                              ? Math.max(0, root.scanBandwidthValues.indexOf(
                                             controller.minimumBandwidthHz))
                              : 0
                enabled: controller && !controller.scanning
                onActivated: if (controller)
                                 controller.setMinimumBandwidthHz(
                                     root.scanBandwidthValues[currentIndex])
                ToolTip.visible: hovered
                ToolTip.text: currentIndex === 0
                              ? "Alle gefundenen Bandbreiten übernehmen"
                              : "Kleinere gemessene Bandbreiten nicht in die Liste aufnehmen"
            }

            Label { text: "Durchläufe:"; color: root.ink }
            SpinBox {
                id: repeatCountSpin
                from: 1
                to: 20
                editable: true
                value: controller ? controller.repeatCount : 1
                enabled: controller && !controller.scanning
                onValueModified: if (controller) controller.setRepeatCount(value)
            }
            CheckBox {
                id: piFilterCheck
                text: "Nur mit PI"
                checked: root.hideWithoutPi
                enabled: controller && !controller.scanning
                onToggled: root.hideWithoutPi = checked
            }

            Item { Layout.fillWidth: true }

            Button {
                text: controller && controller.scanning ? "SCAN LÄUFT …" : "SCAN START"
                enabled: controller && client && client.ready && !controller.scanning
                onClicked: controller.startScan()
            }
            Button {
                text: "STOP"
                enabled: controller && controller.scanning
                onClicked: controller.stopScan()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 3
            color: "#f4f4ef"
            border.width: 1
            border.color: "#85857f"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 1
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    color: root.aluminiumMid
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8
                        Label { Layout.preferredWidth: 100; text: "Frequenz"; color: root.ink; font.bold: true }
                        Label { Layout.preferredWidth: 85; text: "Pegel"; color: root.ink; font.bold: true }
                        Label { Layout.preferredWidth: 62; text: "PI"; color: root.ink; font.bold: true }
                        Label { Layout.fillWidth: true; text: "PS"; color: root.ink; font.bold: true }
                        Label { Layout.preferredWidth: 130; text: "PTY"; color: root.ink; font.bold: true }
                        Label { Layout.preferredWidth: 62; text: "Filter"; color: root.ink; font.bold: true }
                        Label { Layout.preferredWidth: 56; text: "MAP"; color: root.ink; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                    }
                }

                ListView {
                    id: stationList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: controller ? controller.stations : []

                    property int visiblePiCount: {
                        if (!controller)
                            return 0
                        var list = controller.stations
                        var n = 0
                        for (var i = 0; i < list.length; ++i) {
                            var pi = list[i].pi
                            if (pi !== undefined
                                    && pi !== null
                                    && String(pi).trim().length > 0)
                                ++n
                        }
                        return n
                    }

                    ScrollBar.vertical: ScrollBar {}

                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        width: stationList.width
                        readonly property bool hasPi:
                            modelData.pi !== undefined
                            && modelData.pi !== null
                            && String(modelData.pi).trim().length > 0
                        readonly property bool filteredOut:
                            root.hideWithoutPi && !hasPi
                        height: filteredOut ? 0 : 40
                        visible: !filteredOut
                        color: stationMouse.containsMouse ? "#deded8"
                               : (index % 2 === 0 ? "#f4f4ef" : "#e9e9e3")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Label {
                                Layout.preferredWidth: 100
                                text: (modelData.frequencyKhz / 1000).toFixed(3) + " MHz"
                                color: root.ink
                                font.family: "monospace"
                                font.bold: true
                            }
                            Label {
                                Layout.preferredWidth: 85
                                text: Number(modelData.signalLevel).toFixed(1) + " dBµV"
                                color: root.ink
                                font.family: "monospace"
                            }
                            Label {
                                Layout.preferredWidth: 62
                                text: modelData.pi && modelData.pi.length > 0 ? modelData.pi : "—"
                                color: root.ink
                                font.family: "monospace"
                                font.bold: modelData.pi && modelData.pi.length > 0
                            }
                            Label {
                                Layout.fillWidth: true
                                text: modelData.ps && modelData.ps.length > 0 ? modelData.ps : "ohne PS"
                                color: modelData.ps && modelData.ps.length > 0 ? root.ink : root.mutedInk
                                elide: Text.ElideRight
                                font.bold: modelData.ps && modelData.ps.length > 0
                            }
                            Label {
                                Layout.preferredWidth: 130
                                text: modelData.pty && modelData.pty.length > 0 ? modelData.pty : "—"
                                color: root.mutedInk
                                elide: Text.ElideRight
                            }
                            Label {
                                Layout.preferredWidth: 62
                                text: modelData.bandwidthHz > 0
                                      ? Math.round(modelData.bandwidthHz / 1000) + " kHz"
                                      : "Auto"
                                color: root.mutedInk
                                font.family: "monospace"
                            }

                            Button {
                                id: fmdxMapButton
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 30
                                text: "MAP"
                                enabled: hasPi
                                visible: hasPi
                                z: 10

                                ToolTip.visible: hovered
                                ToolTip.text: hasPi
                                              ? "FM-DX Maps: "
                                                + (modelData.frequencyKhz / 1000).toFixed(2)
                                                + " MHz · PI " + String(modelData.pi).trim().toUpperCase()
                                              : ""

                                onClicked: {
                                    var freq = (modelData.frequencyKhz / 1000).toFixed(2)
                                    var pi = String(modelData.pi).trim().toUpperCase()
                                    Qt.openUrlExternally(
                                        "https://maps.fmdx.org/#qth=&freq="
                                        + freq
                                        + "&findPi="
                                        + encodeURIComponent(pi))
                                }
                            }
                        }

                        MouseArea {
                            id: stationMouse
                            anchors.fill: parent
                            anchors.rightMargin: 64
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: controller && !controller.scanning && !filteredOut
                            onClicked: controller.tuneStation(index)
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: controller
                                 && (controller.stationCount === 0
                                     || (root.hideWithoutPi
                                         && stationList.visiblePiCount === 0))
                        text: controller && controller.stationCount > 0
                              ? "Keine Sender mit PI-Code in der Fundliste"
                              : "Noch keine Sender in der Fundliste"
                        color: root.mutedInk
                        font.pixelSize: 14
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                text: controller ? "Fundliste: " + controller.storageFilePath : ""
                color: root.mutedInk
                font.pixelSize: 10
                elide: Text.ElideMiddle
            }
            Button {
                text: "LISTE SPEICHERN"
                enabled: controller && !controller.scanning && controller.stationCount > 0
                onClicked: controller.exportStations()
            }
            Button {
                text: "LISTE LÖSCHEN"
                enabled: controller && !controller.scanning && controller.stationCount > 0
                onClicked: controller.clearStations()
            }
            Button {
                text: "SCHLIESSEN"
                onClicked: root.hide()
            }
        }
    }
}
