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
    minimumHeight: 720
    visible: true
    title: "XdrMini"
    color: woodDark

    property color aluminiumLight: "#efede7"
    property color aluminiumMid: "#c7c1b6"
    property color aluminiumDark: "#8f8a82"
    property color ink: "#171717"
    property color mutedInk: "#57534d"
    property color woodDark: "#4b2d1d"
    property color amber: "#efb334"
    property color amberDark: "#c4871d"
    property color panelDark: "#22201c"
    property color panelDark2: "#2c2824"
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

    function frequencyText() {
        return (xdrClient.frequencyKhz / 1000).toFixed(3) + " MHz"
    }

    function stationText() {
        return xdrClient.psText.length > 0 ? xdrClient.psText : "—"
    }

    function piPtyText() {
        let out = ""

        if (xdrClient.piCode !== "----" && xdrClient.piCode.length > 0)
            out += "PI " + xdrClient.piCode

        if (xdrClient.ptyText.length > 0) {
            if (out.length > 0)
                out += " · "
            out += xdrClient.ptyText.toUpperCase()
        }

        return out.length > 0 ? out : " "
    }

    function titleText() {
        if (xdrClient.rtPlusTitle.length > 0)
            return xdrClient.rtPlusTitle
        return "Kein Titel"
    }

    function artistText() {
        if (xdrClient.rtPlusArtist.length > 0)
            return xdrClient.rtPlusArtist
        return xdrClient.psText.length > 0 ? xdrClient.psText : ""
    }

    function radioTextText() {
        return xdrClient.radioText.length > 0
               ? xdrClient.radioText
               : "Radiotext nicht verfügbar"
    }

    function signalValueClamped() {
        if (!xdrClient.signalAvailable)
            return 0
        return Math.max(0, Math.min(100, xdrClient.signalLevel))
    }

    function signalBlocksFilled() {
        return Math.round(signalValueClamped() / 3.125) // 0..32
    }

    onClosing: function(close) {
        if (xdrClient.connected)
            xdrClient.disconnectFromServer()
        close.accepted = true
    }

    component ActionButton: Rectangle {
        id: actionButton

        property string line1: ""
        property string line2: ""
        property bool active: false
        property bool enabledState: true
        property int buttonHeight: 92

        signal clicked()

        implicitHeight: buttonHeight
        radius: 16
        border.width: 2
        border.color: "#5a544c"
        color: enabledState ? "#d7d1c7" : "#b9b3aa"

        gradient: Gradient {
            GradientStop { position: 0.0; color: enabledState ? "#efede7" : "#cbc5bb" }
            GradientStop { position: 0.45; color: enabledState ? "#d7d1c7" : "#bbb5ac" }
            GradientStop { position: 1.0; color: enabledState ? "#c5bfb5" : "#a9a39a" }
        }

        Column {
            anchors.centerIn: parent
            spacing: line2.length > 0 ? 2 : 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: actionButton.line1
                color: window.ink
                font.pixelSize: 24
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: actionButton.line2.length > 0
                text: actionButton.line2
                color: window.ink
                font.pixelSize: 16
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Rectangle {
            visible: actionButton.active
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            width: Math.min(parent.width * 0.35, 60)
            height: 4
            radius: 2
            color: window.amber
        }

        MouseArea {
            anchors.fill: parent
            enabled: actionButton.enabledState
            onClicked: actionButton.clicked()
        }
    }

    component IconStatusButton: Rectangle {
        id: statusButton

        property string iconText: ""
        property string mainText: ""
        property bool active: false
        property bool enabledState: true
        property int buttonHeight: 102

        signal clicked()

        implicitHeight: buttonHeight
        radius: 16
        border.width: 2
        border.color: "#5a544c"
        color: enabledState ? "#d7d1c7" : "#b9b3aa"

        gradient: Gradient {
            GradientStop { position: 0.0; color: enabledState ? "#efede7" : "#cbc5bb" }
            GradientStop { position: 0.45; color: enabledState ? "#d7d1c7" : "#bbb5ac" }
            GradientStop { position: 1.0; color: enabledState ? "#c5bfb5" : "#a9a39a" }
        }

        Column {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: statusButton.iconText
                color: window.ink
                font.pixelSize: 25
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: statusButton.mainText
                color: window.ink
                font.pixelSize: 18
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            width: Math.min(parent.width * 0.30, 50)
            height: 4
            radius: 2
            color: statusButton.active ? window.amber : "#9d9993"
        }

        MouseArea {
            anchors.fill: parent
            enabled: statusButton.enabledState
            onClicked: statusButton.clicked()
        }
    }

    component SmallHeaderButton: Rectangle {
        id: headerButton

        property string symbol: ""
        property color symbolColor: window.ink
        signal clicked()

        implicitWidth: 58
        implicitHeight: 58
        radius: 12
        border.width: 2
        border.color: "#5a544c"

        gradient: Gradient {
            GradientStop { position: 0.0; color: "#efede7" }
            GradientStop { position: 0.55; color: "#d8d2c8" }
            GradientStop { position: 1.0; color: "#c2bcb2" }
        }

        Text {
            anchors.centerIn: parent
            text: headerButton.symbol
            color: headerButton.symbolColor
            font.pixelSize: 30
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: headerButton.clicked()
        }
    }

    FrequencyDialog {
        id: unusedCustomFrequencyDialog
        visible: false
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
        anchors.margins: 10
        radius: 24
        color: aluminiumMid
        border.width: 2
        border.color: "#2a211b"

        gradient: Gradient {
            GradientStop { position: 0.0; color: "#d2cbc0" }
            GradientStop { position: 0.5; color: "#c7c1b6" }
            GradientStop { position: 1.0; color: "#aea79b" }
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 12
            contentWidth: width
            contentHeight: contentColumn.height + 8
            clip: true

            Column {
                id: contentColumn
                width: parent.width
                spacing: 12

                Rectangle {
                    width: parent.width
                    height: 76
                    radius: 0
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                spacing: 6

                                Text {
                                    text: "XDR"
                                    color: window.ink
                                    font.pixelSize: 34
                                    font.bold: true
                                }

                                Text {
                                    text: "MINI"
                                    color: window.ink
                                    font.pixelSize: 26
                                    font.bold: true
                                }
                            }

                            Text {
                                text: "UKW-MONITOR & RDS-ANALYSATOR"
                                color: window.ink
                                font.pixelSize: 10
                                font.bold: false
                            }
                        }

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            Layout.alignment: Qt.AlignVCenter
                            color: xdrClient.ready
                                   ? "#39b35d"
                                   : (xdrClient.connected ? "#d39b34" : "#746b63")
                            border.width: 1
                            border.color: "#3c3935"
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: xdrClient.ready
                                  ? "ONLINE · " + xdrClient.connectionType
                                  : (xdrClient.connected ? "VERBINDUNG …" : "OFFLINE")
                            color: window.ink
                            font.pixelSize: 14
                            font.bold: true
                        }

                        SmallHeaderButton {
                            symbol: "⚙"
                            onClicked: window.openConnectionDialog()
                        }

                        SmallHeaderButton {
                            symbol: "⏻"
                            symbolColor: "#e0a82d"
                            onClicked: window.disconnectAndQuit()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 250
                    radius: 18
                    color: aluminiumLight
                    border.width: 2
                    border.color: "#6c655d"

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#f0eee8" }
                        GradientStop { position: 1.0; color: "#d7d1c7" }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 12

                        Row {
                            width: parent.width

                            Text {
                                text: "SENDER"
                                color: window.mutedInk
                                font.pixelSize: 18
                            }

                            Text {
                                anchors.right: parent.right
                                text: "FM"
                                color: window.mutedInk
                                font.pixelSize: 18
                            }
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: window.stationText()
                            color: window.ink
                            font.pixelSize: 42
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: window.frequencyText()
                            color: window.ink
                            font.family: "monospace"
                            font.pixelSize: 76
                            font.bold: true

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    frequencyInput.text = (xdrClient.frequencyKhz / 1000).toFixed(3)
                                    frequencyDialog.open()
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width * 0.82
                            height: 2
                            color: "#989187"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: window.piPtyText()
                            color: window.ink
                            font.pixelSize: 22
                        }
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: 10

                    ActionButton {
                        Layout.fillWidth: true
                        line1: "−"
                        line2: xdrClient.smallStepKhz + " kHz"
                        enabledState: xdrClient.ready && !xdrClient.seeking
                        onClicked: xdrClient.stepSmall(-1)
                    }

                    ActionButton {
                        Layout.fillWidth: true
                        line1: "+"
                        line2: xdrClient.smallStepKhz + " kHz"
                        enabledState: xdrClient.ready && !xdrClient.seeking
                        onClicked: xdrClient.stepSmall(1)
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: 10

                    ActionButton {
                        Layout.fillWidth: true
                        line1: "SEEK ◀"
                        enabledState: xdrClient.ready && !xdrClient.seeking
                        active: xdrClient.seeking && xdrClient.seekDirection < 0
                        onClicked: xdrClient.startSeek(-1)
                    }

                    ActionButton {
                        Layout.fillWidth: true
                        line1: "SEEK ▶"
                        enabledState: xdrClient.ready && !xdrClient.seeking
                        active: xdrClient.seeking && xdrClient.seekDirection > 0
                        onClicked: xdrClient.startSeek(1)
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 150
                    radius: 18
                    color: panelDark
                    border.width: 2
                    border.color: "#4e4944"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        Row {
                            width: parent.width

                            Text {
                                text: "SIGNALSTÄRKE"
                                color: "#dfddd7"
                                font.pixelSize: 20
                            }

                            Text {
                                anchors.right: parent.right
                                text: xdrClient.signalAvailable
                                      ? xdrClient.signalLevel.toFixed(1) + " dBµV"
                                      : "— dBµV"
                                color: "#ece7df"
                                font.pixelSize: 24
                                font.bold: true
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 42
                            radius: 10
                            color: "#0f0f0f"
                            border.width: 1
                            border.color: "#4b473f"

                            Row {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 3

                                Repeater {
                                    model: 32
                                    delegate: Rectangle {
                                        width: (parent.width - (31 * 3)) / 32
                                        height: parent.height
                                        radius: 2
                                        color: index < window.signalBlocksFilled()
                                               ? window.amber
                                               : "#57544e"
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width

                            Repeater {
                                model: ["0", "20", "40", "60", "80", "100"]

                                delegate: Text {
                                    width: parent.width / 6
                                    text: modelData
                                    color: "#c6c2bc"
                                    font.pixelSize: 14
                                    horizontalAlignment: index === 0
                                                         ? Text.AlignLeft
                                                         : (index === 5 ? Text.AlignRight
                                                                         : Text.AlignHCenter)
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: 10

                    IconStatusButton {
                        Layout.fillWidth: true
                        iconText: "◉"
                        mainText: xdrClient.forcedMono
                                  ? "MONO"
                                  : (xdrClient.stereo ? "STEREO" : "MONO")
                        active: xdrClient.stereo && !xdrClient.forcedMono
                        onClicked: xdrClient.setForcedMono(!xdrClient.forcedMono)
                    }

                    IconStatusButton {
                        Layout.fillWidth: true
                        iconText: "🚗"
                        mainText: "TMC"
                        active: xdrClient.tmcActive
                        onClicked: {
                            tmcWindow.show()
                            tmcWindow.raise()
                            tmcWindow.requestActivate()
                        }
                    }

                    IconStatusButton {
                        Layout.fillWidth: true
                        iconText: "⌕"
                        mainText: scanController.scanning ? "SCAN …" : "SCAN"
                        active: scanController.scanning
                        onClicked: {
                            scanWindow.show()
                            scanWindow.raise()
                            scanWindow.requestActivate()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 170
                    radius: 18
                    color: aluminiumLight
                    border.width: 2
                    border.color: "#6c655d"

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#f0eee8" }
                        GradientStop { position: 1.0; color: "#d7d1c7" }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 14

                        Rectangle {
                            Layout.preferredWidth: 92
                            Layout.preferredHeight: 92
                            radius: 10
                            color: "#0c73c8"

                            Column {
                                anchors.centerIn: parent
                                spacing: 4

                                Repeater {
                                    model: [18, 28, 40, 56, 40, 28, 18]

                                    delegate: Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 7
                                        height: modelData
                                        radius: 2
                                        color: "#dcefff"
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 4

                            Row {
                                width: parent.width

                                Text {
                                    text: "RDS / TITEL"
                                    color: window.mutedInk
                                    font.pixelSize: 16
                                }

                                Text {
                                    anchors.right: parent.right
                                    text: "RDS"
                                    color: window.mutedInk
                                    font.pixelSize: 16
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: window.titleText()
                                color: window.ink
                                font.pixelSize: 28
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: window.artistText()
                                color: window.ink
                                font.pixelSize: 22
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: "Radiotext: " + window.radioTextText()
                                color: window.mutedInk
                                font.pixelSize: 16
                                wrapMode: Text.WordWrap
                                verticalAlignment: Text.AlignTop
                            }
                        }
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 86
                        radius: 16
                        color: panelDark2
                        border.width: 2
                        border.color: "#5a544c"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            Text {
                                text: "⌘"
                                color: "#e8e2d7"
                                font.pixelSize: 24
                            }

                            Text {
                                Layout.fillWidth: true
                                text: xdrClient.connected ? "VERBINDUNG" : "VERBINDEN"
                                color: "#ece7df"
                                font.pixelSize: 22
                                font.bold: true
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            width: 50
                            height: 4
                            radius: 2
                            color: window.amber
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (xdrClient.connected)
                                    xdrClient.disconnectFromServer()
                                else
                                    window.openConnectionDialog()
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 86
                        radius: 16
                        color: panelDark2
                        border.width: 2
                        border.color: "#5a544c"

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 10

                            Text {
                                text: "⏻"
                                color: "#ece7df"
                                font.pixelSize: 26
                            }

                            Text {
                                text: "AUS"
                                color: "#ece7df"
                                font.pixelSize: 22
                                font.bold: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: window.disconnectAndQuit()
                        }
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "XDR MINI"
                        color: "#4f4a44"
                        font.pixelSize: 14
                    }

                    Text {
                        text: "FM · RDS · TMC"
                        color: "#4f4a44"
                        font.pixelSize: 14
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
