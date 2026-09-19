import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

ApplicationWindow {
    id: window

    width: 680
    height: 420
    minimumWidth: 560
    minimumHeight: 380
    visible: true
    title: "XdrMini"
    color: woodDark

    property color aluminiumLight: "#eeeeea"
    property color aluminiumMid: "#c9c9c3"
    property color aluminiumDark: "#9e9e98"
    property color ink: "#262620"
    property color mutedInk: "#686861"
    property color woodDark: "#4b2d1d"
    property color amber: "#b66c27"
    property var serialPortModel: []

    Settings {
        id: appSettings
        category: "connection"

        property string connectionType: "TCP"
        property string tcpHost: "10.204.190.244"
        property int tcpPort: 7373
        property string usbPort: "/dev/ttyUSB0"
        property int usbBaud: 19200
    }

    function refreshSerialPorts() {
        const ports = xdrClient.availableSerialPorts()
        window.serialPortModel = ports

        if (ports.length === 0) {
            serialPortBox.currentIndex = -1
            return
        }

        const wanted = appSettings.usbPort
        const index = ports.indexOf(wanted)
        serialPortBox.currentIndex = index >= 0 ? index : 0

        if (serialPortBox.currentIndex >= 0)
            appSettings.usbPort = serialPortBox.currentText
    }

    function openConnectionDialog() {
        connectionError.text = ""
        connectionTypeBox.currentIndex =
                appSettings.connectionType === "USB" ? 1 : 0

        tcpHostField.text = appSettings.tcpHost
        tcpPortField.text = String(appSettings.tcpPort)
        passwordField.text = ""

        const baudIndex = baudBox.find(String(appSettings.usbBaud))
        baudBox.currentIndex = baudIndex >= 0 ? baudIndex : 0

        refreshSerialPorts()
        connectionDialog.open()
    }

    function connectRadio() {
        if (connectionTypeBox.currentIndex === 1) {
            if (serialPortBox.currentIndex < 0) {
                connectionError.text = "Kein USB-Anschluss gefunden."
                return
            }

            appSettings.connectionType = "USB"
            appSettings.usbPort = serialPortBox.currentText
            appSettings.usbBaud = Number(baudBox.currentText)

            xdrClient.connectToUsb(appSettings.usbPort,
                                   appSettings.usbBaud)
        } else {
            const port = Number(tcpPortField.text)

            if (tcpHostField.text.trim().length === 0
                    || !isFinite(port) || port < 1 || port > 65535) {
                connectionError.text = "Bitte IP-Adresse und Port prüfen."
                return
            }

            appSettings.connectionType = "TCP"
            appSettings.tcpHost = tcpHostField.text.trim()
            appSettings.tcpPort = port

            xdrClient.connectToServer(appSettings.tcpHost,
                                      appSettings.tcpPort,
                                      passwordField.text)
        }

        connectionError.text = ""
        connectionDialog.close()
    }

    function disconnectAndQuit() {
        if (xdrClient.connected)
            xdrClient.disconnectFromServer()
        Qt.quit()
    }

    onClosing: function(close) {
        if (xdrClient.connected)
            xdrClient.disconnectFromServer()
        close.accepted = true
    }

    Dialog {
        id: frequencyDialog

        title: "Frequenz eingeben"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok | Dialog.Cancel

        onOpened: {
            frequencyInput.forceActiveFocus()
            frequencyInput.selectAll()
        }

        onAccepted: {
            let value = frequencyInput.text.trim()
            value = value.replace(",", ".")

            const mhz = Number(value)

            if (!isNaN(mhz) && mhz >= 87.5 && mhz <= 108.0) {
                xdrClient.setFrequencyKhz(Math.round(mhz * 1000))
            }
        }

        contentItem: ColumnLayout {
            spacing: 8

            Label {
                text: "87.500 bis 108.000 MHz"
            }

            TextField {
                id: frequencyInput
                Layout.preferredWidth: 220
                placeholderText: "z. B. 101.100"
                selectByMouse: true
                font.family: "monospace"
                font.pixelSize: 22
                horizontalAlignment: Text.AlignHCenter

                onAccepted: frequencyDialog.accept()
            }
        }
    }

    ScanWindow {
        id: scanWindow

        controller: scanController
        client: xdrClient
        transientParent: window

        aluminiumLight: window.aluminiumLight
        aluminiumMid: window.aluminiumMid
        ink: window.ink
        mutedInk: window.mutedInk
    }

    TmcWindow {
        id: tmcWindow

        client: xdrClient
        transientParent: window

        aluminiumLight: window.aluminiumLight
        aluminiumMid: window.aluminiumMid
        ink: window.ink
        mutedInk: window.mutedInk
        smallFontSize: 12
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 8
        radius: 5
        color: aluminiumMid
        border.width: 1
        border.color: "#2d211a"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                spacing: 8

                Label {
                    text: "XDR MINI"
                    color: ink
                    font.pixelSize: 17
                    font.bold: true
                }

                Rectangle {
                    width: 11
                    height: 11
                    radius: width / 2
                    color: xdrClient.ready
                           ? "#3f9b55"
                           : (xdrClient.connected ? "#d39b34" : "#746b63")
                    border.width: 1
                    border.color: "#4e4944"
                }

                Label {
                    Layout.fillWidth: true
                    text: xdrClient.ready
                          ? "ONLINE · " + xdrClient.connectionType
                          : (xdrClient.connected ? "VERBINDUNG …" : "OFFLINE")
                    color: mutedInk
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Button {
                    text: xdrClient.connected ? "TRENNEN" : "VERBINDUNG"
                    implicitWidth: 112
                    implicitHeight: 34
                    onClicked: {
                        if (xdrClient.connected)
                            xdrClient.disconnectFromServer()
                        else
                            window.openConnectionDialog()
                    }
                }

                Button {
                    text: "AUS"
                    implicitWidth: 56
                    implicitHeight: 34
                    onClicked: window.disconnectAndQuit()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 130
                radius: 4
                color: aluminiumLight
                border.width: 1
                border.color: "#85857f"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    ColumnLayout {
                        Layout.preferredWidth: 72
                        Layout.fillHeight: true
                        spacing: 4

                        Button {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: "−\n" + xdrClient.smallStepKhz + " kHz"
                            enabled: xdrClient.ready && !xdrClient.seeking
                            font.pixelSize: 13
                            onClicked: xdrClient.stepSmall(-1)
                        }

                        Button {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: "SEEK ◀"
                            enabled: xdrClient.ready && !xdrClient.seeking
                            font.pixelSize: 12
                            onClicked: xdrClient.startSeek(-1)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2

                        Label {
                            id: frequencyLabel

                            Layout.alignment: Qt.AlignHCenter
                            text: (xdrClient.frequencyKhz / 1000).toFixed(3)
                                  + " MHz"
                            color: ink
                            font.family: "monospace"
                            font.pixelSize: 34
                            font.bold: true

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    frequencyInput.text =
                                        (xdrClient.frequencyKhz / 1000).toFixed(3)
                                    frequencyDialog.open()
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Label {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignLeft
                                text: xdrClient.psText.length > 0
                                      ? xdrClient.psText
                                      : ""
                                color: xdrClient.rdsActive
                                       ? "#234a2b"
                                       : mutedInk
                                font.family: "monospace"
                                font.pixelSize: 22
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Label {
                                horizontalAlignment: Text.AlignRight
                                text: xdrClient.piCode === "----" ? "" : xdrClient.piCode
                                color: xdrClient.rdsActive
                                       ? ink
                                       : mutedInk
                                font.family: "monospace"
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }

                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: xdrClient.ptyText.length > 0
                                  ? xdrClient.ptyText
                                  : " "
                            color: mutedInk
                            font.pixelSize: 11
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 72
                        Layout.fillHeight: true
                        spacing: 4

                        Button {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: "+\n" + xdrClient.smallStepKhz + " kHz"
                            enabled: xdrClient.ready && !xdrClient.seeking
                            font.pixelSize: 13
                            onClicked: xdrClient.stepSmall(1)
                        }

                        Button {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: "SEEK ▶"
                            enabled: xdrClient.ready && !xdrClient.seeking
                            font.pixelSize: 12
                            onClicked: xdrClient.startSeek(1)
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 135
                        Layout.fillHeight: true
                        spacing: 7

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 3
                            color: xdrClient.stereo && !xdrClient.forcedMono
                                   ? "#8b2d28" : "#deded8"
                            border.width: 1
                            border.color: "#807b75"

                            Label {
                                anchors.centerIn: parent
                                text: xdrClient.forcedMono
                                      ? "MONO"
                                      : (xdrClient.stereo ? "STEREO" : "MONO")
                                color: xdrClient.stereo && !xdrClient.forcedMono
                                       ? "white" : ink
                                font.bold: true
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 3
                            color: xdrClient.tmcActive ? "#3f7d4b" : "#deded8"
                            border.width: 1
                            border.color: "#807b75"

                            Label {
                                anchors.centerIn: parent
                                text: "TMC · " + xdrClient.tmcMessageCount
                                color: xdrClient.tmcActive ? "white" : ink
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    tmcWindow.show()
                                    tmcWindow.raise()
                                    tmcWindow.requestActivate()
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 3
                            color: scanController.scanning ? "#7a5015" : "#deded8"
                            border.width: 1
                            border.color: "#807b75"

                            Label {
                                anchors.centerIn: parent
                                text: scanController.scanning ? "SCAN …" : "SCAN"
                                color: scanController.scanning ? "white" : ink
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    scanWindow.show()
                                    scanWindow.raise()
                                    scanWindow.requestActivate()
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                spacing: 10

                Label {
                    text: "SIGNAL"
                    color: ink
                    font.pixelSize: 11
                    font.bold: true
                }

                ProgressBar {
                    Layout.fillWidth: true
                    from: 0
                    to: 80
                    value: xdrClient.signalAvailable
                           ? Math.max(0, Math.min(80, xdrClient.signalLevel))
                           : 0
                }

                Label {
                    Layout.preferredWidth: 90
                    horizontalAlignment: Text.AlignRight
                    text: xdrClient.signalAvailable
                          ? xdrClient.signalLevel.toFixed(1) + " dBµV"
                          : "— dBµV"
                    color: ink
                    font.family: "monospace"
                    font.bold: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 4
                color: aluminiumLight
                border.width: 1
                border.color: "#85857f"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 3

                    Label {
                        Layout.fillWidth: true
                        visible: xdrClient.rtPlusTitle.length > 0
                                 || xdrClient.rtPlusArtist.length > 0

                        text: {
                            const title = xdrClient.rtPlusTitle
                            const artist = xdrClient.rtPlusArtist

                            if (title.length > 0 && artist.length > 0)
                                return "♪ " + title + "  ·  " + artist
                            if (title.length > 0)
                                return "♪ " + title
                            if (artist.length > 0)
                                return artist

                            return ""
                        }

                        color: ink
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Label {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        property bool rtPlusDuplicate: {
                            const rt =
                                xdrClient.radioText.trim().toLowerCase()
                            const title =
                                xdrClient.rtPlusTitle.trim().toLowerCase()
                            const artist =
                                xdrClient.rtPlusArtist.trim().toLowerCase()

                            if (rt.length === 0)
                                return false

                            if (title.length > 0 && artist.length > 0)
                                return rt.indexOf(title) >= 0
                                       && rt.indexOf(artist) >= 0

                            if (title.length > 0)
                                return rt.indexOf(title) >= 0

                            if (artist.length > 0)
                                return rt.indexOf(artist) >= 0

                            return false
                        }

                        visible: xdrClient.radioText.length > 0
                                 && !rtPlusDuplicate

                        text: visible ? xdrClient.radioText : ""
                        color: ink
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                text: xdrClient.statusText
                color: mutedInk
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
    }

    Dialog {
        id: connectionDialog

        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(520, window.width - 36)
        modal: true
        focus: true
        title: "Radio verbinden"
        closePolicy: Popup.CloseOnEscape

        contentItem: ColumnLayout {
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Label { text: "Verbindung"; Layout.preferredWidth: 105 }
                ComboBox {
                    id: connectionTypeBox
                    Layout.fillWidth: true
                    model: ["TCP / WLAN", "USB"]
                    onActivated: {
                        appSettings.connectionType =
                                currentIndex === 1 ? "USB" : "TCP"
                        connectionError.text = ""
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 8
                visible: connectionTypeBox.currentIndex === 0

                Label { text: "IP-Adresse" }
                TextField {
                    id: tcpHostField
                    Layout.fillWidth: true
                    placeholderText: "10.204.190.244"
                    selectByMouse: true
                }

                Label { text: "Port" }
                TextField {
                    id: tcpPortField
                    Layout.fillWidth: true
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 1; top: 65535 }
                    selectByMouse: true
                }

                Label { text: "Passwort" }
                TextField {
                    id: passwordField
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholderText: "wird nicht gespeichert"
                    selectByMouse: true
                    onAccepted: window.connectRadio()
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 10
                rowSpacing: 8
                visible: connectionTypeBox.currentIndex === 1

                Label { text: "USB-Port" }
                ComboBox {
                    id: serialPortBox
                    Layout.fillWidth: true
                    model: window.serialPortModel
                    onActivated: appSettings.usbPort = currentText
                }
                Button {
                    text: "Neu laden"
                    onClicked: window.refreshSerialPorts()
                }

                Label { text: "Baudrate" }
                ComboBox {
                    id: baudBox
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    model: ["19200", "115200", "921600"]
                    onActivated:
                        appSettings.usbBaud = Number(currentText)
                }
            }

            Label {
                id: connectionError
                Layout.fillWidth: true
                text: ""
                color: "#9a3d32"
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4

                Item { Layout.fillWidth: true }

                Button {
                    text: "ABBRECHEN"
                    onClicked: connectionDialog.close()
                }

                Button {
                    text: "VERBINDEN"
                    onClicked: window.connectRadio()
                }
            }
        }
    }
}
