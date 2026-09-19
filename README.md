# XdrMini

XdrMini ist eine kleine eigenständige Qt-6-Oberfläche für den vorhandenen
TEF6686/XDR-Empfänger. Sie verwendet denselben `XdrClient` wie XdrTablet.

Enthalten sind:

- TCP/WLAN- und USB-Verbindung
- Frequenz und RDS-Sendername
- Abstimmtasten für die kleine Schrittweite
- Signalstärke sowie Stereo/Mono
- Radiotext und RT+ Titel/Interpret
- TMC-Status und vollständiges TMC-Fenster
- Trennen und Ausschalten
- automatische Erkennung eines getrennten USB-Kabels oder einer abgebrochenen
  WLAN/TCP-Verbindung

## Bauen

Im entpackten Ordner:

```bash
chmod +x build_xdrmini.sh
./build_xdrmini.sh
```

Danach starten:

```bash
./build/bin/xdrmini
```

Wenn Qt-Entwicklungspakete fehlen, werden unter Debian 13 mindestens CMake,
ein C++-Compiler sowie die Qt-6-Module Quick, Network und SerialPort benötigt.

## Verbindung

Über **VERBINDUNG** kann zwischen TCP/WLAN und USB gewählt werden. Als
TCP-Vorgabe sind `10.204.190.244` und Port `7373` eingetragen. Das Passwort
wird absichtlich nicht gespeichert.

Bei USB stehen `19200`, `115200` und `921600` Baud zur Auswahl. Der zuletzt
gewählte Port, die Baudrate, IP-Adresse und TCP-Port werden gespeichert.

Ein Klick auf die TMC-Anzeige öffnet das vollständige TMC-Fenster einschließlich
des Entfernungsfilters.
