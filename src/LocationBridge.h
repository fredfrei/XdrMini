#pragma once

#include <QObject>
#include <QString>

class QGeoPositionInfo;
class QGeoPositionInfoSource;

class LocationBridge : public QObject
{
    Q_OBJECT
    Q_PROPERTY(double latitude READ latitude NOTIFY locationChanged)
    Q_PROPERTY(double longitude READ longitude NOTIFY locationChanged)
    Q_PROPERTY(double horizontalAccuracy READ horizontalAccuracy NOTIFY locationChanged)
    Q_PROPERTY(bool valid READ valid NOTIFY locationChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)

public:
    explicit LocationBridge(QObject *parent = nullptr);

    double latitude() const { return latitude_; }
    double longitude() const { return longitude_; }
    double horizontalAccuracy() const { return horizontalAccuracy_; }
    bool valid() const { return valid_; }
    QString statusText() const { return statusText_; }

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void requestUpdate();

signals:
    void locationChanged();
    void statusTextChanged();

private:
    void ensurePermissionAndStart();
    void beginUpdates();
    void handlePosition(const QGeoPositionInfo &info);
    void setStatusText(const QString &text);

    QGeoPositionInfoSource *source_ = nullptr;
    double latitude_ = 0.0;
    double longitude_ = 0.0;
    double horizontalAccuracy_ = -1.0;
    bool valid_ = false;
    bool runningRequested_ = false;
    QString statusText_ = QStringLiteral("Standort noch nicht verfügbar");
};
