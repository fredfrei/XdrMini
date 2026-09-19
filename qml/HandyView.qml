import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

ApplicationWindow {
    id: window

    width: 412
    height: 915
    minimumWidth: 360
    minimumHeight: 700

    visible: true
    title: "XdrMini"
    color: woodDark

    property color aluminiumLight: "#efede7"
    property color aluminiumMid: "#c8c1b6"
    property color ink: "#171717"
    property color mutedInk: "#615b53"
    property color woodDark: "#4b2d1d"
    property color amber: "#efb334"
    property color darkPanel: "#211f1b"

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

            xdrClient.connectToUsb(
                        appSettings.usbPort,
                        appSettings.usbBaud)
        } else {
            const port = Number(tcpPortField.text)

            if (tcpHostField.text.trim().length === 0
                    || !isFinite(port)
                    || port < 1
                    || port > 65535) {
                connectionError.text =
                        "Bitte IP-Adresse und Port prüfen."
                return
            }

            appSettings.connectionType = "TCP"
            appSettings.tcpHost = tcpHostField.text.trim()
            appSettings.tcpPort = port

            xdrClient.connectToServer(
                        appSettings.tcpHost,
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

    function frequencyText() {
        return (xdrClient.frequencyKhz / 1000).toFixed(3) + " MHz"
    }

    function stationText() {
        return xdrClient.psText.length > 0 ? xdrClient.psText : "—"
    }

    function piPtyText() {
        let result = ""

        if (xdrClient.piCode !== "----"
                && xdrClient.piCode.length > 0) {
            result = "PI " + xdrClient.piCode
        }

        if (xdrClient.ptyText.length > 0) {
            if (result.length > 0)
                result += " · "

            result += xdrClient.ptyText
        }

        return result
    }

    function titleText() {
        return xdrClient.rtPlusTitle.length > 0
                ? xdrClient.rtPlusTitle
                : "Kein Titel"
    }

    function artistText() {
        return xdrClient.rtPlusArtist.length > 0
                ? xdrClient.rtPlusArtist
                : ""
    }

    function radioTextText() {
        return xdrClient.radioText.length > 0
                ? xdrClient.radioText
                : "Kein Radiotext"
    }

    function signalValue() {
        if (!xdrClient.signalAvailable)
            return 0

        return Math.max(0, Math.min(100, xdrClient.signalLevel))
    }

    function signalBlocks() {
        return Math.round(signalValue() / 3.125)
    }

    onClosing: function(close) {
        if (xdrClient.connected)
            xdrClient.disconnectFromServer()

        close.accepted = true
    }

    component MetalButton: Rectangle {
        id: metalButton

        property string text: ""
        property bool enabledState: true
        property bool active: false

        signal clicked()

        implicitHeight: 68
        radius: 12
        border.width: 1
        border.color: "#6c665e"

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: metalButton.enabledState ? "#efede7" : "#cbc6bd"
            }
            GradientStop {
                position: 0.55
                color: metalButton.enabledState ? "#dad4ca" : "#bcb7af"
            }
            GradientStop {
                position: 1.0
                color: metalButton.enabledState ? "#beb8ae" : "#aaa59d"
            }
        }

        Text {
            anchors.centerIn: parent
            text: metalButton.text
            color: window.ink
            font.pixelSize: 21
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            visible: metalButton.active
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            width: 44
            height: 3
            radius: 2
            color: window.amber
        }

        MouseArea {
            anchors.fill: parent
            enabled: metalButton.enabledState
            onClicked: metalButton.clicked()
        }
    }

    component ModeButton: Rectangle {
        id: modeButton

        property string iconText: ""
        property string text: ""
        property bool active: false

        signal clicked()

        implicitHeight: 80
        radius: 12
        border.width: 1
        border.color: "#6c665e"

        gradient: Gradient {
            GradientStop { position: 0; color: "#efede7" }
            GradientStop { position: 1; color: "#c6c0b6" }
        }

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modeButton.iconText
                color: window.ink
                font.pixelSize: 21
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modeButton.text
                color: window.ink
                font.pixelSize: 16
                font.bold: true
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
            width: 36
            height: 3
            radius: 2
            color: modeButton.active ? window.amber : "#9c9891"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: modeButton.clicked()
        }
    }

    component HeaderButton: Rectangle {
        id: headerButton

        property string symbol: ""
        property color symbolColor: window.ink

        signal clicked()

        implicitWidth: 44
        implicitHeight: 44
        radius: 9
        border.width: 1
        border.color: "#625d56"

        gradient: Gradient {
            GradientStop { position: 0; color: "#efede7" }
            GradientStop { position: 1; color: "#bbb5ac" }
        }

        Text {
            anchors.centerIn: parent
            text: headerButton.symbol
            color: headerButton.symbolColor
            font.pixelSize: headerButton.symbol.length > 1 ? 14 : 23
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            anchors.fill: parent
            onClicked: headerButton.clicked()
        }
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

            if (!isNaN(mhz) && mhz >= 87.5 && mhz <= 108.0)
                xdrClient.setFrequencyKhz(Math.round(mhz * 1000))
        }

        contentItem: ColumnLayout {
            spacing: 10

            Label {
                text: "87.500 bis 108.000 MHz"
            }

            TextField {
                id: frequencyInput
                Layout.preferredWidth: 230
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
        anchors.margins: 5

        radius: 20
        border.width: 2
        border.color: "#30241d"

        gradient: Gradient {
            GradientStop { position: 0; color: "#d7d0c4" }
            GradientStop { position: 0.5; color: "#c9c2b7" }
            GradientStop { position: 1; color: "#b5ada1" }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                color: "transparent"

                Column {
                    anchors.fill: parent
                    spacing: 1

                    RowLayout {
                        width: parent.width
                        height: 45
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: "XDR"
                                color: window.ink
                                font.pixelSize: 28
                                font.bold: true
                            }

                            Text {
                                text: "MINI"
                                color: window.ink
                                font.pixelSize: 20
                                font.bold: true
                            }
                        }

                        HeaderButton {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44
                            symbol: "⚙"
                            onClicked: window.openConnectionDialog()
                        }

                        HeaderButton {
                            Layout.preferredWidth: 54
                            Layout.preferredHeight: 44
                            symbol: "AUS"
                            symbolColor: "#d49320"
                            onClicked: window.disconnectAndQuit()
                        }
                    }

                    RowLayout {
                        width: parent.width
                        height: 24
                        spacing: 5

                        Text {
                            Layout.fillWidth: true
                            text: "UKW-MONITOR & RDS-ANALYSATOR"
                            color: window.ink
                            font.pixelSize: 8
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.preferredWidth: 13
                            Layout.preferredHeight: 13
                            radius: 7

                            color:
                                xdrClient.ready
                                ? "#39b35d"
                                : (xdrClient.connected
                                   ? "#d29b36"
                                   : "#817b73")

                            border.width: 1
                            border.color: "#48433d"
                        }

                        Text {
                            text:
                                xdrClient.ready
                                ? "ONLINE · " + xdrClient.connectionType
                                : (xdrClient.connected
                                   ? "VERBINDUNG …"
                                   : "OFFLINE")

                            color: window.ink
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 190

                radius: 14
                border.width: 1
                border.color: "#69635b"

                gradient: Gradient {
                    GradientStop { position: 0; color: "#f2f0ea" }
                    GradientStop { position: 1; color: "#d9d3c9" }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 13
                    spacing: 5

                    RowLayout {
                        width: parent.width
                        height: 22

                        Text {
                            Layout.fillWidth: true
                            text: "SENDER"
                            color: window.mutedInk
                            font.pixelSize: 14
                        }

                        Text {
                            text: "FM"
                            color: window.mutedInk
                            font.pixelSize: 14
                        }
                    }

                    Text {
                        width: parent.width
                        height: 35
                        text: window.stationText()
                        color: window.ink
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 30
                        font.bold: true
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 18
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        height: 62
                        text: window.frequencyText()
                        color: window.ink
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: "monospace"
                        font.pixelSize: 50
                        font.bold: true
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 28

                        MouseArea {
                            anchors.fill: parent

                            onClicked: {
                                frequencyInput.text =
                                        (xdrClient.frequencyKhz / 1000).toFixed(3)
                                frequencyDialog.open()
                            }
                        }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width * 0.80
                        height: 1
                        color: "#908a82"
                    }

                    Text {
                        width: parent.width
                        height: 24
                        text: window.piPtyText()
                        color: window.ink
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 15
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 68
                spacing: 8

                MetalButton {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: "−  " + xdrClient.smallStepKhz + " kHz"
                    enabledState: xdrClient.ready && !xdrClient.seeking
                    onClicked: xdrClient.stepSmall(-1)
                }

                MetalButton {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: "+  " + xdrClient.smallStepKhz + " kHz"
                    enabledState: xdrClient.ready && !xdrClient.seeking
                    onClicked: xdrClient.stepSmall(1)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 112

                radius: 14
                color: window.darkPanel
                border.width: 1
                border.color: "#514b43"

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 7

                    RowLayout {
                        width: parent.width
                        height: 24

                        Text {
                            Layout.fillWidth: true
                            text: "SIGNALSTÄRKE"
                            color: "#dedbd4"
                            font.pixelSize: 15
                        }

                        Text {
                            text:
                                xdrClient.signalAvailable
                                ? xdrClient.signalLevel.toFixed(1) + " dBµV"
                                : "— dBµV"

                            color: "#eeeeea"
                            font.pixelSize: 17
                            font.bold: true
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: 7
                        color: "#101010"
                        border.width: 1
                        border.color: "#504a42"

                        Row {
                            anchors.fill: parent
                            anchors.margins: 5
                            spacing: 2

                            Repeater {
                                model: 32

                                Rectangle {
                                    width: (parent.width - 31 * 2) / 32
                                    height: parent.height
                                    radius: 1
                                    color:
                                        index < window.signalBlocks()
                                        ? window.amber
                                        : "#5a5650"
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 18

                        Repeater {
                            model: ["0", "20", "40", "60", "80", "100"]

                            Text {
                                width: parent.width / 6
                                text: modelData
                                color: "#c8c4bd"
                                font.pixelSize: 10

                                horizontalAlignment:
                                    index === 0
                                    ? Text.AlignLeft
                                    : (index === 5
                                       ? Text.AlignRight
                                       : Text.AlignHCenter)
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                spacing: 8

                ModeButton {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    iconText:
                        xdrClient.forcedMono
                        ? "○"
                        : "◉"

                    text:
                        xdrClient.forcedMono
                        ? "MONO"
                        : (xdrClient.stereo
                           ? "STEREO"
                           : "MONO")

                    active:
                        xdrClient.stereo
                        && !xdrClient.forcedMono

                    onClicked:
                        xdrClient.setForcedMono(!xdrClient.forcedMono)
                }

                ModeButton {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    iconText: "T"
                    text: "TMC"
                    active: xdrClient.tmcActive

                    onClicked: {
                        tmcWindow.show()
                        tmcWindow.raise()
                        tmcWindow.requestActivate()
                    }
                }

                ModeButton {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    iconText: "S"

                    text:
                        scanController.scanning
                        ? "SCAN …"
                        : "SCAN"

                    active: scanController.scanning

                    onClicked: {
                        scanWindow.show()
                        scanWindow.raise()
                        scanWindow.requestActivate()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 120

                radius: 14
                border.width: 1
                border.color: "#69635b"

                gradient: Gradient {
                    GradientStop { position: 0; color: "#f1eee8" }
                    GradientStop { position: 1; color: "#d7d1c7" }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 72
                        Layout.preferredHeight: 72
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 20
                        radius: 7
                        color: "#0873bd"

                        Row {
                            anchors.centerIn: parent
                            spacing: 3

                            Repeater {
                                model: [16, 28, 42, 55, 42, 28, 16]

                                Rectangle {
                                    width: 4
                                    height: modelData
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: 2
                                    color: "#d9efff"
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20

                            Text {
                                Layout.fillWidth: true
                                text: "RDS / TITEL"
                                color: window.mutedInk
                                font.pixelSize: 12
                            }

                            Text {
                                text: "RDS"
                                color: window.mutedInk
                                font.pixelSize: 12
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: window.titleText()
                            color: window.ink
                            font.pixelSize: 20
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: window.artistText()
                            visible: text.length > 0
                            color: window.ink
                            font.pixelSize: 16
                            elide: Text.ElideRight
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            TextArea {
                                text: "Radiotext: " + window.radioTextText()
                                color: window.mutedInk
                                font.pixelSize: 13
                                wrapMode: TextEdit.Wrap
                                readOnly: true
                                selectByMouse: true

                                background: Rectangle {
                                    color: "transparent"
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: connectionDialog

        parent: Overlay.overlay

        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(380, window.width - 24)

        modal: true
        focus: true
        title: "Radio verbinden"
        closePolicy: Popup.CloseOnEscape

        contentItem: ColumnLayout {
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: "Verbindung"
                }

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
                columnSpacing: 8
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

                    validator: IntValidator {
                        bottom: 1
                        top: 65535
                    }

                    selectByMouse: true
                }

                Label { text: "Passwort" }

                TextField {
                    id: passwordField
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholderText: "nicht gespeichert"
                    selectByMouse: true
                    onAccepted: window.connectRadio()
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                visible: connectionTypeBox.currentIndex === 1

                Label { text: "USB-Port" }

                ComboBox {
                    id: serialPortBox
                    Layout.fillWidth: true
                    model: window.serialPortModel
                    onActivated: appSettings.usbPort = currentText
                }

                Label { text: "Baudrate" }

                ComboBox {
                    id: baudBox
                    Layout.fillWidth: true
                    model: ["19200", "115200", "921600"]
                    onActivated: appSettings.usbBaud = Number(currentText)
                }

                Item {
                    width: 1
                    height: 1
                }

                Button {
                    text: "USB neu laden"
                    onClicked: window.refreshSerialPorts()
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

                Button {
                    visible: xdrClient.connected
                    text: "TRENNEN"

                    onClicked: {
                        xdrClient.disconnectFromServer()
                        connectionDialog.close()
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

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
