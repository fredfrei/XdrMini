#include "ScanController.h"
#include "XdrClient.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QSettings>
#include <QStandardPaths>
#include <QStringList>
#include <QVariant>

#include <algorithm>
#include <cmath>

ScanController::ScanController(XdrClient *client, QObject *parent)
    : QObject(parent), client_(client)
{
    stepTimeoutTimer_.setSingleShot(true);
    settleTimer_.setSingleShot(true);
    rdsTimer_.setSingleShot(true);

    connect(&stepTimeoutTimer_, &QTimer::timeout,
            this, &ScanController::onStepTimeout);
    connect(&settleTimer_, &QTimer::timeout,
            this, &ScanController::onSettleTimeout);
    connect(&rdsTimer_, &QTimer::timeout,
            this, &ScanController::onRdsTimeout);

    if (client_) {
        connect(client_, &XdrClient::lastLineChanged,
                this, &ScanController::onClientLineChanged);
    }

    minimumBandwidthHz_ = std::clamp(
        QSettings().value(QStringLiteral("scan/minimumBandwidthHz"), 0).toInt(),
        0, 400000);

    loadStations();
}

QVariantList ScanController::stations() const
{
    QVariantList result;
    result.reserve(stations_.size());

    for (const Station &s : stations_) {
        QVariantMap m;
        m.insert(QStringLiteral("frequencyKhz"), s.frequencyKhz);
        m.insert(QStringLiteral("frequencyMHz"), s.frequencyKhz / 1000.0);
        m.insert(QStringLiteral("pi"), s.pi);
        m.insert(QStringLiteral("ps"), s.ps);
        m.insert(QStringLiteral("pty"), s.pty);
        m.insert(QStringLiteral("signalLevel"), s.signalLevel);
        m.insert(QStringLiteral("wam"), s.wam);
        m.insert(QStringLiteral("usn"), s.usn);
        m.insert(QStringLiteral("bandwidthHz"), s.bandwidthHz);
        m.insert(QStringLiteral("lastSeen"), s.lastSeen.toString(Qt::ISODate));
        result.append(m);
    }

    return result;
}

QString ScanController::storageFilePath() const
{
    const QString dir =
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return QDir(dir).filePath(QStringLiteral("scan_results.json"));
}

void ScanController::setMinimumSignal(double value)
{
    value = std::clamp(value, 0.0, 80.0);

    if (qFuzzyCompare(minimumSignal_ + 1.0, value + 1.0))
        return;

    minimumSignal_ = value;
    emit scanSettingsChanged();
}

void ScanController::setRepeatCount(int value)
{
    if (scanning_)
        return;

    value = std::clamp(value, 1, 20);

    if (repeatCount_ == value)
        return;

    repeatCount_ = value;
    emit scanSettingsChanged();
}

void ScanController::setMinimumBandwidthHz(int value)
{
    if (scanning_)
        return;

    value = std::clamp(value, 0, 400000);
    if (minimumBandwidthHz_ == value)
        return;

    minimumBandwidthHz_ = value;
    QSettings().setValue(QStringLiteral("scan/minimumBandwidthHz"), value);
    emit scanSettingsChanged();
}

void ScanController::startScan()
{
    if (scanning_)
        return;

    if (!client_ || !client_->ready()) {
        setStatusText(QStringLiteral("Scan nicht möglich – Tuner nicht bereit"));
        return;
    }

    if (client_->seeking()) {
        setStatusText(QStringLiteral("Scan nicht möglich – SEEK läuft"));
        return;
    }

    returnFrequencyKhz_ = client_->frequencyKhz();
    currentFrequencyKhz_ = ScanStartKhz;
    currentPass_ = 1;
    newStationsThisScan_ = 0;

    emit newStationsThisScanChanged();

    scanning_ = true;
    phase_ = Phase::Idle;
    setProgress(0);

    emit scanningChanged();
    emit scanProgressChanged();

    setStatusText(QStringLiteral("UKW-Scan 87,500 bis 108,000 MHz · 100-kHz-Raster · Mindest-BW %1")
                      .arg(minimumBandwidthHz_ == 0
                               ? QStringLiteral("aus")
                               : QStringLiteral("%1 kHz").arg(minimumBandwidthHz_ / 1000)));
    tuneCurrentFrequency();
}

void ScanController::stopScan()
{
    if (scanning_)
        finishScan(QStringLiteral("Scan gestoppt"), true);
}

void ScanController::clearStations()
{
    if (scanning_) {
        setStatusText(
            QStringLiteral("Fundliste kann während des Scans nicht gelöscht werden"));
        return;
    }

    if (stations_.isEmpty())
        return;

    stations_.clear();
    saveStations();
    emit stationsChanged();
    setStatusText(QStringLiteral("Scan-Fundliste gelöscht"));
}

QString ScanController::exportStations()
{
    if (scanning_) {
        setStatusText(QStringLiteral("Speichern ist während des Scans nicht möglich"));
        return QString();
    }

    if (stations_.isEmpty()) {
        setStatusText(QStringLiteral("Keine Sender zum Speichern vorhanden"));
        return QString();
    }

    const QString documents =
        QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    const QString directory = QDir(documents).filePath(QStringLiteral("XdrMini"));
    QDir().mkpath(directory);
    const QString path = QDir(directory).filePath(
        QStringLiteral("Scanliste_%1.csv")
            .arg(QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_HHmmss"))));

    auto csvField = [](QString value) {
        value.replace(QLatin1Char('"'), QStringLiteral("\"\""));
        return QStringLiteral("\"") + value + QStringLiteral("\"");
    };

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        setStatusText(QStringLiteral("Scanliste konnte nicht gespeichert werden"));
        return QString();
    }

    file.write("\xEF\xBB\xBF");
    file.write("Frequenz_MHz;PI;PS;PTY;Pegel_dBuV;WAM;USN;Bandbreite_kHz;Zuletzt_gesehen\n");
    for (const Station &s : stations_) {
        const QStringList fields = {
            QString::number(s.frequencyKhz / 1000.0, 'f', 3),
            csvField(s.pi), csvField(s.ps), csvField(s.pty),
            QString::number(s.signalLevel, 'f', 1),
            QString::number(s.wam), QString::number(s.usn),
            QString::number(s.bandwidthHz / 1000),
            csvField(s.lastSeen.toString(Qt::ISODate))
        };
        file.write(fields.join(QLatin1Char(';')).toUtf8());
        file.write("\n");
    }

    if (!file.commit()) {
        setStatusText(QStringLiteral("Scanliste konnte nicht gespeichert werden"));
        return QString();
    }

    setStatusText(QStringLiteral("Scanliste gespeichert: %1").arg(path));
    return path;
}

void ScanController::tuneStation(int index)
{
    if (scanning_ || !client_ || !client_->ready())
        return;

    if (index < 0 || index >= stations_.size())
        return;

    client_->setFrequencyKhz(stations_.at(index).frequencyKhz);
}

void ScanController::setStatusText(const QString &text)
{
    if (statusText_ == text)
        return;

    statusText_ = text;
    emit statusTextChanged();
}

void ScanController::setProgress(int value)
{
    value = std::clamp(value, 0, 100);

    if (progress_ == value)
        return;

    progress_ = value;
    emit scanProgressChanged();
}

void ScanController::resetFrequencyCapture()
{
    probeSignalSum_ = 0.0;
    probeSampleCount_ = 0;
    probeWamSum_ = 0.0;
    probeUsnSum_ = 0.0;
    probeQualitySampleCount_ = 0;

    holdSignalSum_ = 0.0;
    holdSampleCount_ = 0;
    holdWamSum_ = 0.0;
    holdUsnSum_ = 0.0;
    holdQualitySampleCount_ = 0;

    lastWam_ = -1;
    lastUsn_ = -1;
    lastBandwidthHz_ = 0;

    candidateRdsSeen_ = false;
    candidatePi_.clear();
    candidatePiRepeats_ = 0;
}

void ScanController::tuneCurrentFrequency()
{
    if (!scanning_ || !client_)
        return;

    stepTimeoutTimer_.stop();
    settleTimer_.stop();
    rdsTimer_.stop();

    resetFrequencyCapture();

    phase_ = Phase::Settle;
    acceptMeasurements_ = false;

    emit scanProgressChanged();

    client_->setFrequencyKhz(currentFrequencyKhz_);
    settleTimer_.start(SettleMs);

    setStatusText(
        QStringLiteral("%1 MHz – Tuner regelt sich ein")
            .arg(currentFrequencyKhz_ / 1000.0, 0, 'f', 3));
}

void ScanController::onSettleTimeout()
{
    if (!scanning_ || phase_ != Phase::Settle)
        return;

    phase_ = Phase::Probe;
    acceptMeasurements_ = true;
    stepTimeoutTimer_.start(ProbeMs);

    setStatusText(
        QStringLiteral("%1 MHz – Pegelprüfung")
            .arg(currentFrequencyKhz_ / 1000.0, 0, 'f', 3));
}

void ScanController::onStepTimeout()
{
    if (!scanning_ || phase_ != Phase::Probe)
        return;

    acceptMeasurements_ = false;

    if (probeSampleCount_ == 0) {
        setStatusText(
            QStringLiteral("%1 MHz – kein Messwert")
                .arg(currentFrequencyKhz_ / 1000.0, 0, 'f', 3));
        advanceFrequency();
        return;
    }

    const double probeAverage =
        probeSignalSum_ / static_cast<double>(probeSampleCount_);

    if (probeAverage < minimumSignal_) {
        setStatusText(
            QStringLiteral("%1 MHz – %2 dBµV, zu schwach")
                .arg(currentFrequencyKhz_ / 1000.0, 0, 'f', 3)
                .arg(probeAverage, 0, 'f', 1));
        advanceFrequency();
        return;
    }

    if (probeQualitySampleCount_ == 0) {
        setStatusText(
            QStringLiteral("%1 MHz – keine WAM/USN-Messwerte")
                .arg(currentFrequencyKhz_ / 1000.0, 0, 'f', 3));
        advanceFrequency();
        return;
    }

    const double probeAverageWam =
        probeWamSum_ / static_cast<double>(probeQualitySampleCount_);
    const double probeAverageUsn =
        probeUsnSum_ / static_cast<double>(probeQualitySampleCount_);

    if (probeAverageWam >= MaxProbeWam ||
        probeAverageUsn >= MaxProbeUsn) {
        setStatusText(
            QStringLiteral("%1 MHz – %2 dBµV · WAM %3 · USN %4, verwerfen")
                .arg(currentFrequencyKhz_ / 1000.0, 0, 'f', 3)
                .arg(probeAverage, 0, 'f', 1)
                .arg(probeAverageWam, 0, 'f', 1)
                .arg(probeAverageUsn, 0, 'f', 1));
        advanceFrequency();
        return;
    }

    holdSignalSum_ = 0.0;
    holdSampleCount_ = 0;
    holdWamSum_ = 0.0;
    holdUsnSum_ = 0.0;
    holdQualitySampleCount_ = 0;

    candidateRdsSeen_ = false;
    candidatePi_.clear();
    candidatePiRepeats_ = 0;

    phase_ = Phase::Hold;
    acceptMeasurements_ = true;
    rdsTimer_.start(HoldMs);

    setStatusText(
        QStringLiteral("%1 MHz – %2 dBµV · WAM %3 · USN %4 · 8 s beobachten")
            .arg(currentFrequencyKhz_ / 1000.0, 0, 'f', 3)
            .arg(probeAverage, 0, 'f', 1)
            .arg(probeAverageWam, 0, 'f', 1)
            .arg(probeAverageUsn, 0, 'f', 1));
}

void ScanController::onRdsTimeout()
{
    if (!scanning_ || phase_ != Phase::Hold)
        return;

    acceptMeasurements_ = false;
    finishCurrentFrequency();
    advanceFrequency();
}

void ScanController::captureMeasurement(double level, int wam,
                                        int usn, int bandwidthHz)
{
    lastWam_ = wam;
    lastUsn_ = usn;
    lastBandwidthHz_ = bandwidthHz;

    if (phase_ == Phase::Probe) {
        probeSignalSum_ += level;
        ++probeSampleCount_;

        if (wam >= 0 && usn >= 0) {
            probeWamSum_ += wam;
            probeUsnSum_ += usn;
            ++probeQualitySampleCount_;
        }
        return;
    }

    if (phase_ == Phase::Hold) {
        holdSignalSum_ += level;
        ++holdSampleCount_;

        if (wam >= 0 && usn >= 0) {
            holdWamSum_ += wam;
            holdUsnSum_ += usn;
            ++holdQualitySampleCount_;
        }
    }
}

void ScanController::captureRdsLine(const QString &line)
{
    if (phase_ != Phase::Hold)
        return;

    if (line.startsWith(QLatin1Char('R'))) {
        candidateRdsSeen_ = true;
        return;
    }

    if (!line.startsWith(QLatin1Char('P')) || line.size() < 5)
        return;

    const QString pi = line.mid(1, 4).toUpper();

    if (!validPi(pi))
        return;

    candidateRdsSeen_ = true;

    if (candidatePi_ == pi) {
        ++candidatePiRepeats_;
    } else {
        candidatePi_ = pi;
        candidatePiRepeats_ = 1;
    }

    if (candidatePiRepeats_ >= 2) {
        setStatusText(
            QStringLiteral("%1 MHz – PI %2 bestätigt")
                .arg(currentFrequencyKhz_ / 1000.0, 0, 'f', 3)
                .arg(candidatePi_));
    }
}

void ScanController::finishCurrentFrequency()
{
    double finalSignal = 0.0;

    if (holdSampleCount_ > 0) {
        finalSignal =
            holdSignalSum_ / static_cast<double>(holdSampleCount_);
    } else if (probeSampleCount_ > 0) {
        finalSignal =
            probeSignalSum_ / static_cast<double>(probeSampleCount_);
    } else {
        return;
    }

    if (finalSignal < minimumSignal_)
        return;

    // Reiner Ergebnisfilter: Die Tuner-Bandbreite wird nicht verändert.
    // Sender unterhalb der gewählten, vom Tuner gemeldeten Bandbreite
    // werden nicht in die Fundliste übernommen.
    if (minimumBandwidthHz_ > 0 && lastBandwidthHz_ < minimumBandwidthHz_)
        return;

    Station s;
    s.frequencyKhz = currentFrequencyKhz_;
    s.signalLevel = finalSignal;

    if (holdQualitySampleCount_ > 0) {
        s.wam = static_cast<int>(std::lround(
            holdWamSum_ / static_cast<double>(holdQualitySampleCount_)));
        s.usn = static_cast<int>(std::lround(
            holdUsnSum_ / static_cast<double>(holdQualitySampleCount_)));
    } else {
        s.wam = lastWam_;
        s.usn = lastUsn_;
    }

    s.bandwidthHz = lastBandwidthHz_;
    s.lastSeen = QDateTime::currentDateTime();

    if (candidateRdsSeen_ && candidatePiRepeats_ >= 2)
        s.pi = candidatePi_;

    // PS/PTY nur bei bestätigtem PI übernehmen. So landen keine RDS-Reste
    // des vorherigen Senders in einem Eintrag ohne bestätigten PI.
    if (client_ && !s.pi.isEmpty()) {
        s.ps = client_->psText().trimmed();
        s.pty = client_->ptyText().trimmed();
    }

    if (upsertStation(s)) {
        ++newStationsThisScan_;
        emit newStationsThisScanChanged();
    }
}

void ScanController::advanceFrequency()
{
    stepTimeoutTimer_.stop();
    settleTimer_.stop();
    rdsTimer_.stop();

    acceptMeasurements_ = false;
    phase_ = Phase::Idle;

    const int pointsPerPass =
        (ScanEndKhz - ScanStartKhz) / ScanStepKhz + 1;
    const int doneThisPass =
        (currentFrequencyKhz_ - ScanStartKhz) / ScanStepKhz + 1;
    const int totalPoints = pointsPerPass * repeatCount_;
    const int completedPoints =
        (currentPass_ - 1) * pointsPerPass + doneThisPass;

    setProgress((completedPoints * 100) / totalPoints);

    if (currentFrequencyKhz_ >= ScanEndKhz) {
        if (currentPass_ < repeatCount_) {
            ++currentPass_;
            currentFrequencyKhz_ = ScanStartKhz;

            setStatusText(
                QStringLiteral("Durchlauf %1/%2 startet")
                    .arg(currentPass_)
                    .arg(repeatCount_));

            emit scanProgressChanged();
            tuneCurrentFrequency();
            return;
        }

        finishScan(
            QStringLiteral("Scan beendet – %1 Durchlauf/Durchläufe · %2 neue Sender")
                .arg(repeatCount_)
                .arg(newStationsThisScan_),
            true);
        return;
    }

    currentFrequencyKhz_ += ScanStepKhz;
    emit scanProgressChanged();
    tuneCurrentFrequency();
}

void ScanController::finishScan(const QString &message, bool restoreFrequency)
{
    stepTimeoutTimer_.stop();
    settleTimer_.stop();
    rdsTimer_.stop();

    phase_ = Phase::Idle;
    acceptMeasurements_ = false;

    if (scanning_) {
        scanning_ = false;
        emit scanningChanged();
    }

    setProgress(100);
    setStatusText(message);

    if (restoreFrequency && client_ && client_->ready())
        client_->setFrequencyKhz(returnFrequencyKhz_);
}

void ScanController::onClientLineChanged()
{
    if (!scanning_ || !client_)
        return;

    const QString line = client_->lastLine().trimmed();

    if (line.isEmpty())
        return;

    captureRdsLine(line);

    // Sobald PI und ein vollständiger PS vorhanden sind, ist die
    // Senderidentifikation abgeschlossen. Dann muss nicht bis zum
    // Ende der 8-Sekunden-Wartezeit gewartet werden.
    //
    // XdrClient veröffentlicht psText() erst nach allen vier
    // PS-Segmenten, daher ist ein nichtleerer PS hier vollständig.
    if (phase_ == Phase::Hold &&
        candidatePiRepeats_ >= 2 &&
        client_ &&
        client_->piCode().trimmed().toUpper() == candidatePi_ &&
        !client_->psText().trimmed().isEmpty()) {

        rdsTimer_.stop();
        acceptMeasurements_ = false;

        setStatusText(
            QStringLiteral("%1 MHz – PI %2 · PS %3 · weiter")
                .arg(currentFrequencyKhz_ / 1000.0, 0, 'f', 3)
                .arg(candidatePi_)
                .arg(client_->psText().trimmed()));

        finishCurrentFrequency();
        advanceFrequency();
        return;
    }

    if (!acceptMeasurements_)
        return;

    double level = 0.0;
    int wam = -1;
    int usn = -1;
    int bandwidthHz = 0;

    if (!parseMeasurementLine(line, level, wam, usn, bandwidthHz))
        return;

    captureMeasurement(level, wam, usn, bandwidthHz);
}

bool ScanController::parseMeasurementLine(const QString &line, double &level,
                                          int &wam, int &usn,
                                          int &bandwidthHz) const
{
    if (!(line.startsWith(QStringLiteral("Ss")) ||
          line.startsWith(QStringLiteral("Sm")) ||
          line.startsWith(QStringLiteral("SS")) ||
          line.startsWith(QStringLiteral("SM"))))
        return false;

    const QStringList fields =
        line.mid(2).split(QLatin1Char(','));

    if (fields.isEmpty())
        return false;

    bool ok = false;
    level = fields.at(0).toDouble(&ok);

    if (!ok)
        return false;

    wam = -1;
    usn = -1;
    bandwidthHz = 0;

    if (fields.size() >= 2) {
        wam = fields.at(1).toInt(&ok);
        if (!ok)
            wam = -1;
    }

    if (fields.size() >= 3) {
        usn = fields.at(2).toInt(&ok);
        if (!ok)
            usn = -1;
    }

    if (fields.size() >= 4) {
        int bw = fields.at(3).toInt(&ok);

        if (ok && bw >= 0) {
            if (bw < 1000)
                bw *= 1000;
            bandwidthHz = bw;
        }
    }

    return true;
}

bool ScanController::validPi(const QString &pi)
{
    if (pi.size() != 4)
        return false;

    bool ok = false;
    const uint value = pi.toUInt(&ok, 16);

    return ok && value != 0x0000U && value != 0xFFFFU;
}

int ScanController::findExistingStation(const Station &candidate) const
{
    for (int i = 0; i < stations_.size(); ++i) {
        const Station &existing = stations_.at(i);
        const int distance =
            std::abs(existing.frequencyKhz - candidate.frequencyKhz);

        // Derselbe 100-kHz-Rasterpunkt.
        if (distance <= 25)
            return i;

        if (!candidate.pi.isEmpty() &&
            candidate.pi == existing.pi &&
            distance <= 100)
            return i;
    }

    return -1;
}

bool ScanController::upsertStation(const Station &candidate)
{
    const int index = findExistingStation(candidate);

    if (index < 0) {
        stations_.append(candidate);
        sortStations();
        saveStations();
        emit stationsChanged();
        return true;
    }

    Station &existing = stations_[index];

    const bool sameFrequency =
        std::abs(candidate.frequencyKhz - existing.frequencyKhz) <= 25;
    const bool piChanged =
        !candidate.pi.isEmpty() && candidate.pi != existing.pi;

    if (sameFrequency)
        existing.frequencyKhz = candidate.frequencyKhz;

    if (!candidate.pi.isEmpty())
        existing.pi = candidate.pi;

    if (piChanged) {
        existing.ps = candidate.ps;
        existing.pty = candidate.pty;
    } else {
        if (!candidate.ps.isEmpty())
            existing.ps = candidate.ps;
        if (!candidate.pty.isEmpty())
            existing.pty = candidate.pty;
    }

    // Bei jedem neuen Scan desselben Senders werden diese Werte erneuert.
    existing.signalLevel = candidate.signalLevel;
    existing.wam = candidate.wam;
    existing.usn = candidate.usn;
    existing.bandwidthHz = candidate.bandwidthHz;
    existing.lastSeen = candidate.lastSeen;

    sortStations();
    saveStations();
    emit stationsChanged();

    return false;
}

void ScanController::sortStations()
{
    std::sort(stations_.begin(), stations_.end(),
              [](const Station &a, const Station &b) {
                  return a.frequencyKhz < b.frequencyKhz;
              });
}

void ScanController::loadStations()
{
    QFile file(storageFilePath());

    if (!file.open(QIODevice::ReadOnly))
        return;

    const QJsonDocument doc =
        QJsonDocument::fromJson(file.readAll());

    if (!doc.isArray())
        return;

    stations_.clear();

    for (const QJsonValue &value : doc.array()) {
        if (!value.isObject())
            continue;

        const QJsonObject o = value.toObject();

        Station s;
        s.frequencyKhz =
            o.value(QStringLiteral("frequencyKhz")).toInt();

        if (s.frequencyKhz < ScanStartKhz ||
            s.frequencyKhz > ScanEndKhz)
            continue;

        s.pi =
            o.value(QStringLiteral("pi")).toString().toUpper();
        s.ps =
            o.value(QStringLiteral("ps")).toString();
        s.pty =
            o.value(QStringLiteral("pty")).toString();
        s.signalLevel =
            o.value(QStringLiteral("signalLevel")).toDouble();
        s.wam = o.contains(QStringLiteral("wam"))
            ? o.value(QStringLiteral("wam")).toInt(-1)
            : o.value(QStringLiteral("cci")).toInt(-1);
        s.usn = o.contains(QStringLiteral("usn"))
            ? o.value(QStringLiteral("usn")).toInt(-1)
            : o.value(QStringLiteral("aci")).toInt(-1);
        s.bandwidthHz =
            o.value(QStringLiteral("bandwidthHz")).toInt();
        s.lastSeen =
            QDateTime::fromString(
                o.value(QStringLiteral("lastSeen")).toString(),
                Qt::ISODate);

        stations_.append(s);
    }

    sortStations();
}

void ScanController::saveStations() const
{
    const QString path = storageFilePath();

    QDir().mkpath(QFileInfo(path).absolutePath());

    QJsonArray array;

    for (const Station &s : stations_) {
        QJsonObject o;
        o.insert(QStringLiteral("frequencyKhz"), s.frequencyKhz);
        o.insert(QStringLiteral("pi"), s.pi);
        o.insert(QStringLiteral("ps"), s.ps);
        o.insert(QStringLiteral("pty"), s.pty);
        o.insert(QStringLiteral("signalLevel"), s.signalLevel);
        o.insert(QStringLiteral("wam"), s.wam);
        o.insert(QStringLiteral("usn"), s.usn);
        o.insert(QStringLiteral("bandwidthHz"), s.bandwidthHz);
        o.insert(QStringLiteral("lastSeen"),
                 s.lastSeen.toString(Qt::ISODate));
        array.append(o);
    }

    QSaveFile file(path);

    if (!file.open(QIODevice::WriteOnly))
        return;

    file.write(
        QJsonDocument(array).toJson(QJsonDocument::Indented));
    file.commit();
}

// XDRMINI_SCAN_MIN_BW_V1
