#pragma once

#include <QObject>
#include <QDateTime>
#include <QTimer>
#include <QVariant>
#include <QVector>

class XdrClient;

class ScanController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(int currentFrequencyKhz READ currentFrequencyKhz NOTIFY scanProgressChanged)
    Q_PROPERTY(int progress READ progress NOTIFY scanProgressChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)
    Q_PROPERTY(QVariantList stations READ stations NOTIFY stationsChanged)
    Q_PROPERTY(int stationCount READ stationCount NOTIFY stationsChanged)
    Q_PROPERTY(int newStationsThisScan READ newStationsThisScan NOTIFY newStationsThisScanChanged)
    Q_PROPERTY(double minimumSignal READ minimumSignal WRITE setMinimumSignal NOTIFY scanSettingsChanged)
    Q_PROPERTY(int repeatCount READ repeatCount WRITE setRepeatCount NOTIFY scanSettingsChanged)
    Q_PROPERTY(int currentPass READ currentPass NOTIFY scanProgressChanged)
    Q_PROPERTY(int minimumBandwidthHz READ minimumBandwidthHz WRITE setMinimumBandwidthHz NOTIFY scanSettingsChanged)
    Q_PROPERTY(QString storageFilePath READ storageFilePath CONSTANT)

public:
    explicit ScanController(XdrClient *client, QObject *parent = nullptr);

    bool scanning() const { return scanning_; }
    int currentFrequencyKhz() const { return currentFrequencyKhz_; }
    int progress() const { return progress_; }
    QString statusText() const { return statusText_; }
    QVariantList stations() const;
    int stationCount() const { return stations_.size(); }
    int newStationsThisScan() const { return newStationsThisScan_; }
    double minimumSignal() const { return minimumSignal_; }
    int repeatCount() const { return repeatCount_; }
    int currentPass() const { return currentPass_; }
    int minimumBandwidthHz() const { return minimumBandwidthHz_; }
    QString storageFilePath() const;

    Q_INVOKABLE void startScan();
    Q_INVOKABLE void stopScan();
    Q_INVOKABLE void clearStations();
    Q_INVOKABLE void tuneStation(int index);
    Q_INVOKABLE void setMinimumSignal(double value);
    Q_INVOKABLE void setRepeatCount(int value);
    Q_INVOKABLE void setMinimumBandwidthHz(int value);
    Q_INVOKABLE QString exportStations();

signals:
    void scanningChanged();
    void scanProgressChanged();
    void statusTextChanged();
    void stationsChanged();
    void newStationsThisScanChanged();
    void scanSettingsChanged();

private slots:
    void onClientLineChanged();
    void onStepTimeout();
    void onSettleTimeout();
    void onRdsTimeout();

private:
    enum class Phase { Idle, Settle, Probe, Hold };

    struct Station {
        int frequencyKhz = 0;
        QString pi;
        QString ps;
        QString pty;
        double signalLevel = 0.0;
        int wam = -1;
        int usn = -1;
        int bandwidthHz = 0;
        QDateTime lastSeen;
    };

    static constexpr int ScanStartKhz = 87500;
    static constexpr int ScanEndKhz = 108000;
    static constexpr int ScanStepKhz = 100;

    // Pro Frequenz:
    // 1,5 s Einregelzeit + 0,5 s Prüfphase.
    // Nur bei ausreichendem Pegel weitere 8 s beobachten.
    // Starke Frequenz bleibt damit insgesamt ca. 10 s eingestellt.
    static constexpr int SettleMs = 1500;
    static constexpr int ProbeMs = 500;
    static constexpr int HoldMs = 8000;

    // PE5PVB-artige Qualitätsprüfung.
    // Kleine WAM/USN-Werte bedeuten bessere Empfangsqualität.
    static constexpr double MaxProbeWam = 30.0;
    static constexpr double MaxProbeUsn = 20.0;

    void setStatusText(const QString &text);
    void setProgress(int value);

    void tuneCurrentFrequency();
    void advanceFrequency();
    void resetFrequencyCapture();
    void finishCurrentFrequency();
    void finishScan(const QString &message, bool restoreFrequency);

    void captureRdsLine(const QString &line);
    void captureMeasurement(double level, int wam, int usn, int bandwidthHz);

    bool parseMeasurementLine(const QString &line, double &level,
                              int &wam, int &usn, int &bandwidthHz) const;
    static bool validPi(const QString &pi);

    int findExistingStation(const Station &candidate) const;
    bool upsertStation(const Station &candidate);
    void sortStations();
    void loadStations();
    void saveStations() const;

    XdrClient *client_ = nullptr;
    Phase phase_ = Phase::Idle;

    QTimer stepTimeoutTimer_;
    QTimer settleTimer_;
    QTimer rdsTimer_;

    bool scanning_ = false;
    bool acceptMeasurements_ = false;
    int currentFrequencyKhz_ = ScanStartKhz;
    int returnFrequencyKhz_ = ScanStartKhz;
    int progress_ = 0;
    QString statusText_ = QStringLiteral("Scan bereit");
    double minimumSignal_ = 20.0;
    int repeatCount_ = 1;
    int currentPass_ = 1;
    int minimumBandwidthHz_ = 0;
    int newStationsThisScan_ = 0;

    double probeSignalSum_ = 0.0;
    int probeSampleCount_ = 0;
    double probeWamSum_ = 0.0;
    double probeUsnSum_ = 0.0;
    int probeQualitySampleCount_ = 0;

    double holdSignalSum_ = 0.0;
    int holdSampleCount_ = 0;
    double holdWamSum_ = 0.0;
    double holdUsnSum_ = 0.0;
    int holdQualitySampleCount_ = 0;

    int lastWam_ = -1;
    int lastUsn_ = -1;
    int lastBandwidthHz_ = 0;

    bool candidateRdsSeen_ = false;
    QString candidatePi_;
    int candidatePiRepeats_ = 0;

    QVector<Station> stations_;
};
